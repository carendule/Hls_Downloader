import 'package:flutter/material.dart';

import 'package:hls_downloader/hls_downloader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HlsDownloader.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  String status = 'NaN';
  String size = 'NaN';
  String speed = 'NaN';
  String path = 'NaN';
  double value = 0;

  final smallTestUrl = 'https://vkceyugu.cdn.bspapp.com/VKCEYUGU-uni4934e7b/c4d93960-5643-11eb-a16f-5b3e54966275.m3u8';
  final largeTestUrl = 'https://s1.yh5125.com/20211031/Sr7Xed5I/index.m3u8';

  @override
  void initState() {
    super.initState();
    HlsDownloader.addListener(
      onProgress:(p0) {
        setState(() {
          status = p0.status?? 'created';
          size = '${p0.current ?? 0}/${p0.total ?? 0}';
          value = p0.progress;
          speed = p0.speed ?? 'NaN';
          path = p0.path?? '';
        });
      },
      onError: (p0) {
        setState(() {
          status = p0.status?? 'error';
          size = '${p0.current ?? 0}/${p0.total ?? 0}';
          value = p0.progress;
          speed = p0.speed ?? 'NaN';
          path = p0.path?? '';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('status:$status'),
              Text('size:$size'),
              Text('speed:$speed'),
              Text('path:$path'),
              LinearProgressIndicator(
                value: value,
              ),
              const Padding(padding: EdgeInsets.only(top: 10),),
              Container(
                width: 180,
                height: 56,
                color: Colors.grey,
                child: InkWell(
                  child: const Text('start download'),
                  onTap: () {
                    HlsDownloader.addTask(smallTestUrl)
                        .then((value){
                          debugPrint('downloader created:${value}');
                            setState(() {
                              status = 'created';
                            });
                        });
                  },
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 10),),
              Container(
                width: 180,
                height: 56,
                color: Colors.grey,
                child: InkWell(
                  child: const Text('cancel download'),
                  onTap: () {
                    HlsDownloader.deleteTask(smallTestUrl)
                        .then((value) {
                          debugPrint('downloader delete:${value}');
                          setState(() {
                            status = 'deleted';
                          });
                        });
                  },
                ),
              ),
              const Padding(padding: EdgeInsets.only(top: 10),),
              Container(
                width: 180,
                height: 56,
                color: Colors.grey,
                child: InkWell(
                  child: const Text('restart download'),
                  onTap: () {
                    HlsDownloader.restartTask(smallTestUrl)
                        .then((value) {
                      debugPrint('restart:${value}');
                      setState(() {
                        status = 'restart';
                      });
                    });
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
