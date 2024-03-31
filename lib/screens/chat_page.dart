import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late RTCPeerConnection _peerConnection;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  File? _imageFile;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _createPeerConnection();
  }

  Future<void> _createPeerConnection() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final Map<String, dynamic> constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    _peerConnection.onDataChannel = (RTCDataChannel dataChannel) {
      dataChannel.onMessage = (RTCDataChannelMessage message) {
        setState(() {
          _messages.add(message.text);
        });
      };
    };
  }

  Future<void> _sendMessage(String message) async {
    RTCDataChannel dataChannel = await _peerConnection.createDataChannel('chat', RTCDataChannelInit());
    dataChannel.onDataChannelState = (RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        dataChannel.send(RTCDataChannelMessage.fromBinary(utf8.encode(message)));
      }
    };
    await _firestore.collection('messages').add({
      'message': message,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> _sendVideo(File videoFile) async {
    List<int> videoBytes = await videoFile.readAsBytes();
    final message = 'video:${base64Encode(videoBytes)}';

    RTCDataChannel dataChannel = await _peerConnection.createDataChannel('chat', RTCDataChannelInit());
    dataChannel.onDataChannelState = (RTCDataChannelState state) async {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        dataChannel.send(RTCDataChannelMessage.fromBinary(utf8.encode(message)));
      }
      await _firestore.collection('messages').add({
        'message': message,
        'timestamp': Timestamp.now(),
      });
    };
  }

  Future<void> _sendImage(File imageFile) async {
    List<int> imageBytes = await imageFile.readAsBytes();
    final message = 'image:${base64Encode(imageBytes)}';
    RTCDataChannel dataChannel = await _peerConnection.createDataChannel('chat', RTCDataChannelInit());
    dataChannel.onDataChannelState = (RTCDataChannelState state) async {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        dataChannel.send(RTCDataChannelMessage.fromBinary(utf8.encode(message)));
      }
      await _firestore.collection('messages').add({
        'message': message,
        'timestamp': Timestamp.now(),
      });
    };
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _videoPlayerController = VideoPlayerController.file(File(pickedFile.path))
          ..initialize().then((_) {
            setState(() {});
          });
        _messageController.text = 'Video selected';
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
        final message = 'image:${base64Encode(_imageFile!.readAsBytesSync())}';
        _messageController.text = message;
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  String _getFormattedTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebRTC Chat'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('messages').orderBy('timestamp').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(),
                  );
                }
                _messages.clear();
                for (var doc in snapshot.data!.docs) {
                  _messages.add(doc['message']);
                }
                return ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    if (message.startsWith('image:')) {
                      final imageBytes = base64Decode(message.split(':')[1]);
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Image.memory(imageBytes),
                            ),
                            Text(
                              _getFormattedTimestamp(snapshot.data!.docs[index]['timestamp']),
                              style: TextStyle(fontSize: 12.0, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    } else if (message.startsWith('video:')) {
                      final videoBytes = base64Decode(message.split(':')[1]);
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: _videoPlayerController != null && _videoPlayerController!.value.isInitialized
                                    ? VideoPlayer(_videoPlayerController!)
                                    : Container(),
                              ),
                            ),
                            Text(
                              _getFormattedTimestamp(snapshot.data!.docs[index]['timestamp']),
                              style: TextStyle(fontSize: 12.0, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(message),
                            Text(
                              _getFormattedTimestamp(snapshot.data!.docs[index]['timestamp']),
                              style: TextStyle(fontSize: 12.0, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: Icon(Icons.videocam),
                  onPressed: _pickVideo,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () async {
                    final message = _messageController.text;
                    if (message.isNotEmpty) {
                      if (_imageFile != null && message.startsWith('Image selected')) {
                        print("image submitting==============>");
                       await _sendImage(_imageFile!);
                        print("image submitted==============>");
                      } else if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized && message.startsWith('Video selected')) {
                        print("video submitting==============>");
                      await _sendVideo(File(_videoPlayerController!.dataSource));
                        print("video submitted==============>");

                      } else {
                        print("message submitting==============>");
                        _sendMessage(message);
                      }
                      _messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
