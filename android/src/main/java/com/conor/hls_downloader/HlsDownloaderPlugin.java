package com.conor.hls_downloader;

import android.content.Context;
import android.os.FileUtils;
import android.os.Handler;
import android.os.Looper;

import com.jeffmony.downloader.VideoDownloadConfig;
import com.jeffmony.downloader.VideoDownloadManager;
import com.jeffmony.downloader.listener.DownloadListener;
import com.jeffmony.downloader.model.VideoTaskItem;
import com.jeffmony.downloader.utils.VideoDownloadUtils;

import org.json.JSONObject;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.core.Observable;
import io.reactivex.rxjava3.core.Scheduler;
import io.reactivex.rxjava3.functions.Consumer;
import io.reactivex.rxjava3.schedulers.Schedulers;
import jaygoo.local.server.M3U8HttpServer;

/** HlsDownloaderPlugin */
public class HlsDownloaderPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

  private static final String EVENT_CHANNEL = "m3u8_helper/event";
  private static final String METHOD_CHANNEL = "m3u8_helper/method";


  private final Object initializationLock = new Object();
  private Context context;
  private MethodChannel methodChannel;
  private EventChannel eventChannel;
  private EventChannel.EventSink sink;
  private M3U8HttpServer server = new M3U8HttpServer();

  private Map<String,VideoTaskItem> tasks = new HashMap<>();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    onAttachedToEngine(binding.getApplicationContext(),binding.getBinaryMessenger());
  }

  private void onAttachedToEngine(Context application, BinaryMessenger messenger){
    synchronized (initializationLock){
      context = application;
      methodChannel = new MethodChannel(messenger,METHOD_CHANNEL);
      methodChannel.setMethodCallHandler(this);
      eventChannel = new EventChannel(messenger,EVENT_CHANNEL);
      eventChannel.setStreamHandler(this);
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    context = null;
    if(eventChannel != null) eventChannel.setStreamHandler(null);
    eventChannel = null;
    if(methodChannel != null) methodChannel.setMethodCallHandler(null);
    methodChannel = null;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    switch (call.method){
      case "init":
        initDownloadManager(call);
        result.success(true);
        break;
      case "addTask":
        if(!isArgumentVaild(call,"url")){
          result.error("0001",
                  "Url must not null",null);
          break;
        }
        String taskUrl = call.argument("url");
        boolean isAdd = addTaskToDownload(taskUrl);
        if(isAdd)
          result.success(taskUrl);
        else
          result.error("0002",
                  "Download Listener not set, cannot add a task", null);
        break;
      case "deleteTask":
        if(!isArgumentVaild(call,"url")){
          result.error("0001",
                  "Url must not null",null);
          break;
        }
        String deleteUrl = call.argument("url");
        deleteTask(deleteUrl);
        result.success(deleteUrl);
        break;
      case "restartTask":
        if(!isArgumentVaild(call,"url")){
          result.error("0001",
                  "Url must not null",null);
          break;
        }
        String restartUrl = call.argument("url");
        restartTask(restartUrl);
        result.success(restartUrl);
        break;
      case "startServer":
        startServer();
        result.success(null);
        break;
      case "stopServer":
        stopServer();
        result.success(null);
        break;
      case "convertPathToUrl":
        if(!isArgumentVaild(call,"path")){
          result.error("0004",
                  "path must not null",null);
          break;
        }
        result.success(convertPath(call.argument("path")));
        break;
    }
  }

  private boolean registedListener = false;
  private final DownloadListener listener = new DownloadListener(){

    @Override
    public void onDownloadStart(VideoTaskItem item) {
      Map<String,Object> params = new HashMap<>();
      params.put("url",item.getUrl());
      params.put("status","start");
      params.put("total",item.getTotalTs());
      params.put("current",item.getCurTs());
      params.put("speed",item.getSpeedString());
      params.put("progress",0f);
      sendSuccessToFlutter(params);
    }

    @Override
    public void onDownloadProgress(VideoTaskItem item) {
      if(sink == null){
        return;
      }
      Map<String,Object> params = new HashMap<>();
      params.put("url",item.getUrl());
      params.put("status","progress");
      params.put("total",item.getTotalTs());
      params.put("current",item.getCurTs());
      params.put("speed",item.getSpeedString());
      params.put("progress",item.getPercent()/100f);
      sendSuccessToFlutter(params);
    }

    @Override
    public void onDownloadSuccess(VideoTaskItem item) {
      tasks.remove(item.getUrl());
      if(sink == null){
        return;
      }
      Map<String,Object> params = new HashMap<>();
      params.put("url",item.getUrl());
      params.put("status","success");
      params.put("total",item.getTotalTs());
      params.put("current",item.getCurTs());
      params.put("speed",item.getSpeedString());
      params.put("progress",1f);
      params.put("path",item.getFilePath());
      sendSuccessToFlutter(params);
    }

    @Override
    public void onDownloadError(VideoTaskItem item) {
      Map<String,Object> params = new HashMap<>();
      params.put("url",item.getUrl());
      params.put("status","error");
      params.put("total",item.getTotalTs());
      params.put("current",item.getCurTs());
      params.put("speed",item.getSpeedString());
      params.put("progress",item.getPercent()/100f);
      sendErrorToFlutter("0003","Download Error",params);
    }
  };

  @Override
  public void onListen(Object arguments, EventChannel.EventSink events) {
    sink = events;
    if(registedListener){
      return;
    }
    VideoDownloadManager.getInstance().setGlobalDownloadListener(listener);
    registedListener = true;
  }

  @Override
  public void onCancel(Object arguments) {
    if(sink != null){
      sink.endOfStream();
      sink = null;
    }
    registedListener = false;
  }

  private void initDownloadManager(MethodCall call){
    VideoDownloadManager.Build config = new VideoDownloadManager.Build(context);
    File cacheRoot;
    if(isArgumentVaild(call,"directory")){
      cacheRoot = new File(context.getFilesDir().getAbsolutePath()
              +"/"+call.argument("directory"));
    }else {
      cacheRoot = new File(context.getFilesDir().getAbsolutePath()
              +"/download");
    }
    if(!cacheRoot.exists()){
      cacheRoot.mkdirs();
    }

    config.setCacheRoot(cacheRoot.getAbsolutePath());
    config.setIgnoreCertErrors(true);
    config.setShouldM3U8Merged(false);

    if(isArgumentVaild(call,"concurrent")){
      config.setConcurrentCount(call.argument("concurrent"));
    }else {
      config.setConcurrentCount(2);
    }

    if(isArgumentVaild(call,"read_time") && isArgumentVaild(call,"conn_time")) {
      config.setTimeOut(call.argument("read_time"), call.argument("conn_time"));
    }

    VideoDownloadManager.getInstance().initConfig(config.buildConfig());
  }

  private boolean addTaskToDownload(String url){
    if(!registedListener || sink == null){
      return false;
    }
    VideoTaskItem task;
    if(tasks.containsKey(url)){
      task = tasks.get(url);
    }else {
      task = new VideoTaskItem(url);
      tasks.put(url,task);
    }
    VideoDownloadManager.getInstance().startDownload(task);
    return true;
  }

  private void restartTask(String url){
    VideoTaskItem item = tasks.get(url);
    if(item != null){
      if(item.isErrorState()){
        addTaskToDownload(url);
        return;
      }
    }
    deleteTask(url);
    addTaskToDownload(url);
  }

  private void deleteTask(String url){
    VideoDownloadManager.getInstance()
            .deleteVideoTask(url,true);
    tasks.remove(url);
  }

  private boolean isArgumentVaild(MethodCall call,String name){
    return call.hasArgument(name) && call.argument(name) != JSONObject.NULL;
  }

  private void startServer(){
    server.execute();
  }

  private String convertPath(String path){
    return server.createLocalHttpUrl(path);
  }

  private void stopServer(){
    server.finish();
  }

  private void sendSuccessToFlutter(Map<String,Object> params){
    Observable.just(params)
            .observeOn(AndroidSchedulers.mainThread())
            .subscribe(stringObjectMap -> {
              if(sink != null){
                sink.success(stringObjectMap);
              }
            }, Throwable::printStackTrace);
  }

  private void sendErrorToFlutter(String code,String message,Map<String,Object> params){
    Observable.combineLatest(Observable.just(code),Observable.just(message),Observable.just(params),
            ErrorObject::new)
            .observeOn(AndroidSchedulers.mainThread())
            .subscribe(errorObject -> {
              if(sink != null){
                sink.error(errorObject.code,errorObject.message,errorObject.params);
              }
            }, Throwable::printStackTrace);
  }

}


class ErrorObject{

  String code;
  String message;
  Map<String,Object> params;

  public ErrorObject(String code, String message, Map<String, Object> params) {
    this.code = code;
    this.message = message;
    this.params = params;
  }
}
