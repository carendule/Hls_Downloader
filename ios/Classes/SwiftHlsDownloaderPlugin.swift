import Flutter
import UIKit
import CommonCrypto
import RxSwift

public class SwiftHlsDownloaderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  
    static let EVENT_CHANNEL = "m3u8_helper/event";
    static let METHOD_CHANNEL = "m3u8_helper/method";
    
  public static func register(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(name: METHOD_CHANNEL, binaryMessenger: registrar.messenger())
      let event = FlutterEventChannel(name: EVENT_CHANNEL, binaryMessenger: registrar.messenger())
      let instance = SwiftHlsDownloaderPlugin()
      registrar.addMethodCallDelegate(instance, channel: channel)
      event.setStreamHandler(instance)
  }

    private var sink:FlutterEventSink? = nil
    private var cacheRoot = NSHomeDirectory() + "/Library/Caches"
    private var concurrent = 3
    private var isInit = false
    private var downloadings:Dictionary<String,DownloadTask> = [:]
    
      public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          let arguments = call.arguments as? Dictionary<String, Any>
          switch(call.method){
          case "init":
              cacheRoot = cacheRoot +  (arguments?["directory"] as? String ?? "/download")
              if(!checkDirectory(path: cacheRoot)){
                  result(
                    FlutterError(
                        code: "0005",
                        message: "Directory Create Failed",
                        details: nil
                    )
                  )
                  break
              }
              concurrent = arguments?["concurrent"] as? Int ?? 3
              isInit = true
              result(true)
              break;
          case "addTask":
              if !isInit{
                  result(
                    FlutterError(
                        code: "0002",
                        message: "Download not init,cannot add task",
                        details: nil
                    )
                  )
                  break
              }
              let taskUrl = arguments?["url"] as? String
              if(taskUrl == nil){
                  result(
                    FlutterError(
                        code: "0001",
                        message: "Url must not null",
                        details: nil
                    )
                  );
                  break
              }
              let isAdd = addTaskToDownload(url: taskUrl!)
              if(isAdd){
                  result(taskUrl)
              }else{
                  result(FlutterError(
                    code: "0002",
                    message: "Cannot add a task",
                    details: nil)
                  )
              }
              break
          case "deleteTask":
              let taskUrl = arguments?["url"] as? String
              if(taskUrl == nil){
                  result(
                    FlutterError(
                        code: "0001",
                        message: "Url must not null",
                        details: nil
                    )
                  );
                  break
              }
              deleteTask(url: taskUrl!)
              result(taskUrl)
              break
          case "restartTask":
              let taskUrl = arguments?["url"] as? String
              if(taskUrl == nil){
                  result(
                    FlutterError(
                        code: "0001",
                        message: "Url must not null",
                        details: nil
                    )
                  );
                  break
              }
              restartTask(url: taskUrl!)
              result(taskUrl)
              break
          case "startServer":
              break
          case "stopServer":
              stopServer()
              result(nil)
              break
          case "convertPathToUrl":
              let path = arguments?["path"] as? String
              if(path == nil){
                  result(
                    FlutterError(
                        code: "0004",
                        message: "path must not null",
                        details: nil
                    )
                  );
                  break
              }
              result(convertPath(path: path!))
              break
          default:
              break
          }
      }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        for task in downloadings.values{
            task.updateSink(sink: events)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if(sink != nil){
            for task in downloadings.values{
                task.updateSink(sink: nil)
            }
            sink?(FlutterEndOfEventStream)
            sink = nil
        }
        return nil
    }
    
    private func checkDirectory(path:String) -> Bool{
        if !FileManager.default.fileExists(atPath: cacheRoot){
            do{
                try FileManager.default.createDirectory(atPath: cacheRoot, withIntermediateDirectories: true, attributes: nil)
            }catch{
                return false
            }
        }
        return true
    }
    
    private func addTaskToDownload(url:String) -> Bool{
        let output = cacheRoot + "/" + url.md5
        if(!checkDirectory(path: output)){
            return false
        }
        print("add Task in path:"+output)
        let task = DownloadTask.init(url: url, savePath: output,concurrent: concurrent)
        task.updateSink(sink: sink)
        task.register()
        task.taskFinish = {(url) in
            self.downloadings.removeValue(forKey: url)
        }
        task.taskError = {(url) in
            self.downloadings.removeValue(forKey: url)
        }
        task.start()
        downloadings.updateValue(task, forKey: url)
        return true
    }
    
    private func deleteTask(url:String){
        downloadings[url]?.stop()
        downloadings.removeValue(forKey: url)
        do{
            let path =  downloadings[url]?.getSavePath() ?? cacheRoot + "/" + url.md5
            print("remove Task in path:"+path)
            try FileManager.default.removeItem(atPath: path)
        }catch{
            print(error.localizedDescription)
        }
    }
    
    private func restartTask(url:String){
        let downloader = downloadings[url]
        if(downloader != nil){
            downloader!.resume()
            return
        }
        downloadings.removeValue(forKey: url)
        _ = addTaskToDownload(url: url)
    }

    private func convertPath(path:String) -> String{
        AriaM3U8LocalServer.shared.start(withPath: cacheRoot + "/" + path,port: 10241)
        return (AriaM3U8LocalServer.shared.getLocalServerURLString() ?? "http://localhost:10241").appending("/index.m3u8")
    }
    
    private func stopServer(){
        AriaM3U8LocalServer.shared.stop()
    }
    
    private func sendSuccessToFlutter(params:Dictionary<String,Any>){
        DispatchQueue.main.async {
            self.sink?(params)
        }
    }
    
    private func sendErrorToFlutter(code:String, message:String, params:Dictionary<String,Any>){
        DispatchQueue.main.async {
            self.sink?(FlutterError(
                code: code,
                message:message,
                details: params
            )
          )
        }
    }
  
}

public class DownloadTask {
    
    private var status:Dictionary<String,Any> = [
        "status":"created",
        "total":0,
        "current":0,
        "speed":"0KB/s",
        "progress":Double(0)
    ]
    
    private let savePath:String
    private let url:String
    private var sink:FlutterEventSink?
    private let downloader:AriaM3U8Downloader
    private let concurrent:Int?
    
    @objc open var taskFinish: ((String) -> ())?
    
    @objc open var taskError: ((String) -> ())?
    
    init(url:String ,savePath:String,concurrent:Int? = 3){
        status.updateValue(url, forKey: "url")
        self.url = url
        self.savePath = savePath
        self.concurrent = concurrent
        downloader = AriaM3U8Downloader.init(withURLString: url, outputPath: savePath)
    }
    
    public func getSavePath() -> String{
        return savePath
    }
    
    public func updateSink(sink:FlutterEventSink?){
        self.sink = sink
    }
    
    public func register(){
        if(downloader.downloadStatus != AriaDownloadStatus.isReadyToDownload){
            return
        }
        downloader.maxConcurrentOperationCount = concurrent ?? 3
        downloader.downloadStartExeBlock = {
            self.status["status"] = "start"
            self.sendSuccessToFlutter(params: self.status)
        }
        downloader.downloadM3U8StatusExeBlock = {(current,total) in
            self.status["total"] = total
            self.status["current"] = current
            self.sendSuccessToFlutter(params: self.status)
        }
        downloader.downloadFileProgressExeBlock = {(progress) in
            self.status["status"] = "progress"
            self.status["progress"] = Double(progress)
            self.sendSuccessToFlutter(params: self.status)
        }
        downloader.downloadCompleteExeBlock = {
            self.status["status"] = "success"
            self.status["path"] = self.url.md5
            self.sendSuccessToFlutter(params: self.status)
            self.taskFinish?(self.url)
        }
        downloader.downloadTSFailureExeBlock = {(name) in
            self.downloader.stop();
            self.status["status"] = "error"
            self.sendErrorToFlutter(
                code: "0003",
                message: "Download Error",
                params: self.status
            )
            self.taskError?(self.url)
        }
    }
    
    public func start(){
        downloader.start()
    }
    
    public func stop(){
        downloader.stop()
    }
    
    public func resume(){
        downloader.resume()
    }
    
    private func sendSuccessToFlutter(params:Dictionary<String,Any>){
        DispatchQueue.main.async {
            self.sink?(params)
        }
    }
    
    private func sendErrorToFlutter(code:String, message:String, params:Dictionary<String,Any>){
        DispatchQueue.main.async {
            self.sink?(FlutterError(
                code: code,
                message:message,
                details: params
            )
          )
        }
    }
    
}

public extension String {
    /* ################################################################## */
    /**
     - returns: the String, as an MD5 hash.
     */
    var md5: String {
        let str = self.cString(using: String.Encoding.utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: String.Encoding.utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(str!, strLen, result)

        let hash = NSMutableString()

        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }

        result.deallocate()
        return hash as String
    }
}
