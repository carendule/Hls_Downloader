
import 'dart:async';
import 'package:flutter/services.dart';

class HlsDownloader {

  static const MethodChannel mChannel = MethodChannel('m3u8_helper/method');
  static const EventChannel eChannel = EventChannel('m3u8_helper/event');


  static Future<void> init({
    String directory = '/download',
    concurrent = 3,
    read_timeout = 60*1000,
    conn_timeout = 60*1000
  }) async {
   await mChannel.invokeMethod('init',{
      'directory':directory,
      'concurrent':concurrent,
      'read_time':read_timeout,
      'conn_time':conn_timeout
    });
  }

  static void addListener({
    required Function(DownloadStatus) onProgress,
    required Function(DownloadStatus) onError
  }){
    eChannel.receiveBroadcastStream().listen((event) {
      onProgress.call(handleEvent(event));
    },onError:(object){
      if(object is PlatformException){
        onError(handleEvent(object.details));
        return;
      }
      onError(DownloadStatus());
    },cancelOnError: false);
  }

  static DownloadStatus handleEvent(dynamic event){
    DownloadStatus status = DownloadStatus();
    status.url = event['url']?.toString();
    status.status = event['status']?.toString();
    status.current = event['current'];
    status.total = event['total'];
    status.speed = event['speed']?.toString();
    status.progress = event['progress'];
    status.path = event['path'];
    return status;
  }

  static Future<dynamic> addTask(String url) async{
    return mChannel.invokeMethod('addTask',{'url':url});
  }

  static Future<dynamic> restartTask(String url) async{
    return mChannel.invokeMethod('restartTask',{'url':url});
  }

  static Future<dynamic> deleteTask(String url) async {
    return mChannel.invokeMethod('deleteTask',{'url':url});
  }

  static Future<void> startServer() async {
    await mChannel.invokeMethod('startServer');
  }

  static Future<void> stopServer() async {
    await mChannel.invokeMethod('stopServer');
  }

  static Future<String> convertPathToUrl(String path) async {
    return await mChannel.invokeMethod('convertPathToUrl',{'path':path});
  }
}

class DownloadStatus{

  String? url;
  String? status;
  int? current;
  int? total;
  String? speed;
  double progress = 0;
  String? path;

}
