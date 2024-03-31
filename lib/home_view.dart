
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:webrtc_demo/services/signaling.dart';



final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
final List<RTCVideoRenderer> remoteRendererList = <RTCVideoRenderer>[];
final RTCVideoRenderer remoteList = RTCVideoRenderer();
late final LocalParticipant participant;

class HomePage extends StatefulWidget {
  final String userType;

  const HomePage({Key? key, required this.userType}) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String? userType;
  DateTime? compareDate;
  int i = 0;
  bool? isMute = false;
  bool? isVideoCam = false;
  Signaling signaling = Signaling();
  String? roomId;
  MediaStream? stream;
  bool isRemoteConnected = false;
  final db = FirebaseFirestore.instance;
  int userIndex = 0;
  int maxParticipants = 3;
  int? userCurrentIndex;

  @override
  void initState() {
    Future.delayed(
      const Duration(milliseconds: 300),
      () async {
        userType = widget.userType;
        _localRenderer.initialize();
        _remoteRenderer.initialize();
        if (userType == 'H') {
          var collection = FirebaseFirestore.instance.collection('ActiveCallers');
          var snapshots = await collection.get();
          for (var doc in snapshots.docs) {
            await doc.reference.delete();
          }
          setState(() {});
          signaling.openUserMedia(_localRenderer, _remoteRenderer).then(
            (value) async {
              {
                roomId = await signaling.createRoom(_localRenderer);
                setState(() {});
              }
            },
          );
        } else if (userType == 'V') {
          signaling.openUserMedia(_localRenderer, _remoteRenderer);
          setState(() {});
          signaling.getData();
        }
        signaling.onAddRemoteStream = ((stream) {
          _remoteRenderer.srcObject = stream;
          initRenderers();

          setState(
            () => isRemoteConnected = (!isRemoteConnected),
          );
        });
        if (remoteRendererList.isNotEmpty) {
          remoteList.initialize();
        }
        initForegroundTask();
      },
    );
    print('---------------------------------------------------------------------------5');
    super.initState();
  }


  void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription: 'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'sendButton', text: 'Send'),
          const NotificationButton(id: 'testButton', text: 'Test'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }


  Future<void> initRenderers() async {
    for (int i = 0; i < maxParticipants; i++) {
      remoteRendererList.add(_remoteRenderer);
      remoteRendererList[i].initialize();
      setState(() {});
    }
  }

  Widget bottomNavigationDesign(context) {
    return Container(
      height: 80,
      color: Colors.white,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Row( // Replace Align with Row
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                IconButton(
                  onPressed: () {
                    setState(
                          () {
                        isMute = !isMute!;
                        _localRenderer.srcObject!.getAudioTracks()[0].enabled =
                        !(_localRenderer.srcObject!.getAudioTracks()[0].enabled);
                      },
                    );
                  },
                  icon: Icon(isMute! ? Icons.mic_off_rounded : Icons.mic),
                ),
                const Text(
                  "Mute",
                  style: TextStyle(color: Color.fromRGBO(108, 112, 114, 1), fontSize: 14),
                )
              ],
            ),
            Column(
              children: [
                IconButton(
                  onPressed: () {
                    setState(
                          () {
                        isVideoCam = !isVideoCam!;
                        _localRenderer.srcObject!.getVideoTracks()[0].enabled =
                        !(_localRenderer.srcObject!.getVideoTracks()[0].enabled);
                      },
                    );
                  },
                  icon: Icon(!isVideoCam! ? Icons.videocam : Icons.videocam_off),
                ),
                const Text(
                  "Off",
                  style: TextStyle(color: Color.fromRGBO(108, 112, 114, 1), fontSize: 14),
                )
              ],
            ),
            Column(
              children: [
                IconButton(
                  onPressed: () async => _localRenderer.srcObject!.getVideoTracks()[0].switchCamera(),
                  icon: const Icon(Icons.cameraswitch),
                ),
                const Text(
                  "Switch camera",
                  style: TextStyle(color: Color.fromRGBO(108, 112, 114, 1), fontSize: 14),
                )
              ],
            ),
            // Column(
            //   children: [
            //     IconButton(
            //       onPressed: () async {
            //         return await makeScreenSharing();
            //       },
            //       icon: const Icon(Icons.mobile_screen_share),
            //     ),
            //     const Text(
            //       "Screen sharing",
            //       style: TextStyle(color: Color.fromRGBO(108, 112, 114, 1), fontSize: 14),
            //     ),
            //   ],
            // ),
            StreamBuilder<QuerySnapshot>(
              stream: db.collection('ActiveCallers').snapshots(),
              builder: (context, snapshot) {
                return Column(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: snapshot.data!.docs.map(
                              (doc) {
                            return IconButton(
                              onPressed: () async { setState(
                                    () => signaling.hangUp(context, _localRenderer, _remoteRenderer,roomId!));},
                              icon: const Icon(Icons.call_end_rounded,color: Colors.red,)
                            );
                          },
                        ).toList(),
                      ),
                    ),
                    const Text(
                      "Hang Up",
                      style: TextStyle(color: Color.fromRGBO(108, 112, 114, 1), fontSize: 14),
                    )
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  // void enableScreenShare() async {
  //   if (lkPlatformIs(PlatformType.android)) {
  //     print("PlatformType.android --> ${PlatformType.android}");
  //     // Android specific
  //     requestBackgroundPermission([bool isRetry = false]) async {
  //       print("isRetry --> $isRetry");
  //       // Required for android screenshare.
  //       try {
  //         bool hasPermissions = await FlutterBackground.hasPermissions;
  //         print("hasPermissions --> $hasPermissions");
  //         if (!isRetry) {
  //           const androidConfig = FlutterBackgroundAndroidConfig(
  //             notificationTitle: 'Screen Sharing',
  //             notificationText: 'LiveKit Example is sharing the screen.',
  //             notificationImportance: AndroidNotificationImportance.Default,
  //             notificationIcon: AndroidResource(name: 'livekit_ic_launcher', defType: 'mipmap'),
  //           );
  //           hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
  //         }
  //         if (hasPermissions && !FlutterBackground.isBackgroundExecutionEnabled) {}
  //         await FlutterBackground.enableBackgroundExecution();
  //       } catch (e) {
  //         if (!isRetry) {
  //           return await Future<void>.delayed(const Duration(seconds: 1), () => requestBackgroundPermission(true));
  //         }
  //         print('could not publish video: $e');
  //       }
  //     }
  //
  //     await requestBackgroundPermission();
  //   }
  //   if (lkPlatformIs(PlatformType.iOS)) {
  //     var track = await LocalVideoTrack.createScreenShareTrack(
  //       const ScreenShareCaptureOptions(
  //         useiOSBroadcastExtension: true,
  //         maxFrameRate: 15.0,
  //       ),
  //     );
  //     await participant.publishVideoTrack(track);
  //     return;
  //   }
  //   await participant.setScreenShareEnabled(true, captureScreenAudio: true);
  // }


  // Future<void> makeScreenSharing() async {
  //   Future.delayed(
  //     const Duration(milliseconds: 1500),
  //     () async {
  //       final mediaConstraints = <String, dynamic>{'audio': true, 'video': true};
  //       print("mediaConstraints --> $mediaConstraints");
  //
  //       try {
  //         var stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
  //         localStream = stream;
  //         _localRenderer.srcObject = localStream;
  //       } catch (e) {
  //         print(e.toString());
  //       }
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    Widget videoWidget;

    if (!isRemoteConnected) {
      videoWidget = SizedBox(
        height: MediaQuery.of(context).size.height * .80,
        width: MediaQuery.of(context).size.width,
        child: RTCVideoView(_localRenderer, mirror: true),
      );
    } else if (remoteRendererList.isNotEmpty) {
      videoWidget = Column(
        children: [
          Expanded(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .80,
              width: MediaQuery.of(context).size.width,
              child: RTCVideoView(_remoteRenderer),
            ),
          ),
        ],
      );
    } else {
      videoWidget = SizedBox(
        height: MediaQuery.of(context).size.height * .80,
        width: MediaQuery.of(context).size.width,
        child: RTCVideoView(_remoteRenderer),
      );
    }

    Widget userTypeWidget;
    if (userType == 'V') {
      userTypeWidget = Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: db.collection('ActiveCallers').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else {
                return SizedBox(
                  height: MediaQuery.of(context).size.height / 2,
                  width: MediaQuery.of(context).size.width / 2,
                  child: ListView(
                    children: snapshot.data!.docs.map(
                          (doc) {
                        return Card(
                          child: ListTile(
                            onTap: () {
                              signaling.joinRoom(doc.get('id'), _remoteRenderer);
                              setState(() {});
                            },
                            tileColor: Colors.white70,
                            title: Text(doc.get('name') ?? "test"),
                            trailing: const Icon(Icons.call, color: Colors.green),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                );
              }
            },
          ),
        ],
      );
    } else {
      userTypeWidget = SizedBox();
    }

    return WithForegroundTask(
      child: SafeArea(
        child: Scaffold(
          bottomNavigationBar: bottomNavigationDesign(context),
          body: Stack(
            alignment: Alignment.bottomRight,
            children: [
              videoWidget,
              userTypeWidget,
            ],
          ),
        ),
      ),
    );
  }
}


