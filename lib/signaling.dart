import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

MediaStream? localStream;
typedef StreamStateCallback = void Function(MediaStream stream);

class Signaling {
  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
    ]
  };

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  RTCPeerConnection? peerConnection;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;

  Future<String> createRoom(RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc();
    final activecallers = db.collection('ActiveCallers');

    print('Create PeerConnection with configuration: $configuration');

    peerConnection =
        await createPeerConnection(configuration, offerSdpConstraints);

    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    var callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got candidate: ${candidate.toMap()}');
      callerCandidatesCollection.add(candidate.toMap());
    };
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    print('Created offer: $offer');

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};

    await roomRef.set(roomWithOffer);
    var roomId = roomRef.id;
    print('New room created with SDK offer. Room ID: $roomId');
    currentRoomText = 'Current room is $roomId - You are the caller!';

    peerConnection?.onTrack = (RTCTrackEvent event) {
      print('Got remote track: ${event.streams[0]}');

      event.streams[0].getTracks().forEach((track) {
        print('Add a track to the remoteStream $track');
        remoteStream?.addTrack(track);
      });
    };

    QuerySnapshot querySnapshot = await _activeUserCollRef.get();
    int aciveusercount =
        querySnapshot.docs.map((doc) => doc.data()).toList().length + 1;
    final acitvecallerjson = {
      'id': roomId,
      'userId' : "",
      'name': 'user_$aciveusercount',
      'start-on': DateTime.now()
    };
    activecallers.add(acitvecallerjson);
    roomRef.snapshots().listen((snapshot) async {
      print('Got updated room: ${snapshot.data()}');

      Map<String, dynamic> data = snapshot.data() != null ? snapshot.data() as Map<String, dynamic> : {};
      if (peerConnection?.getRemoteDescription() != null &&
          data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        print("Someone tried to connect");
        await peerConnection?.setRemoteDescription(answer);
      }
    });
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
    return roomId;
  }

  final CollectionReference _activeUserCollRef =
      FirebaseFirestore.instance.collection('ActiveCallers');

  Future<List> getData() async {
    QuerySnapshot querySnapshot = await _activeUserCollRef.get();
    List listData = querySnapshot.docs.map((doc) => doc.data()).toList();
    print("datalist --> ${listData.length}");
    return listData;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteVideo) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc(roomId);
    var roomSnapshot = await roomRef.get();
    print('Got room  roomSnapshot.exists --> ${roomSnapshot.exists}');

    if (roomSnapshot.exists) {
      print('Create PeerConnection with configuration: $configuration');
      peerConnection = await createPeerConnection(configuration);

      registerPeerConnectionListeners();

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      // Code for collecting ICE candidates below
      var calleeCandidatesCollection = roomRef.collection('calleeCandidates');
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate == null) {
          print('onIceCandidate: complete!');
          return;
        }
        print('onIceCandidate: ${candidate.toMap()}');
        calleeCandidatesCollection.add(candidate.toMap());
      };

      peerConnection?.onTrack = (RTCTrackEvent event) {
        print('Got remote track: ${event.streams[0]}');
        event.streams[0].getTracks().forEach((track) {
          print('Add a track to the remoteStream: $track');
          remoteStream?.addTrack(track);
        });
      };
      var data = roomSnapshot.data() as Map<String, dynamic>;
      print('Got offer $data');
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      var answer = await peerConnection!.createAnswer();
      print('Created Answer $answer');

      await peerConnection!.setLocalDescription(answer);

      Map<String, dynamic> roomWithAnswer = {
        'answer': {'type': answer.type, 'sdp': answer.sdp}
      };

      await roomRef.update(roomWithAnswer);
      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (var document in snapshot.docChanges) {
          var data = document.doc.data() as Map<String, dynamic>;
          print(data);
          print('Got new remote ICE candidate: $data');
          peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    }
  }

  Future<void> openUserMedia(
    RTCVideoRenderer localVideo,
    RTCVideoRenderer remoteVideo,
  ) async {
    var stream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});

    localVideo.srcObject = stream;
    localStream = stream;
    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  void hangUp(BuildContext context, RTCVideoRenderer localVideo, RTCVideoRenderer remoteVideo, String roomId) async {
    try {

      localVideo.srcObject!.getTracks().forEach((track) => track.stop());

      if (peerConnection != null) {
        await peerConnection!.close();
      }

      localVideo.srcObject = null;
      remoteVideo.srcObject = null;
      localStream!.dispose();
      localVideo.dispose();
      remoteVideo.dispose();

      await deleteActiveCallers();

      await deleteRoomDocuments(roomId);

      Navigator.of(context).pop();
    } catch (e) {
      print('Error occurred during hang up: $e');
    }
  }

  Future<void> deleteActiveCallers() async {
    try {
      var collection = FirebaseFirestore.instance.collection('ActiveCallers');
      var snapshots = await collection.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting active callers: $e');
    }
  }

  Future<void> deleteRoomDocuments(String roomId) async {
    try {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection('rooms').doc(roomId);

      var collectionRoom = FirebaseFirestore.instance.collection('rooms');
      var snapshot = await collectionRoom.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      var callerCandidates = await roomRef.collection('callerCandidates').get();
      for (var document in callerCandidates.docs) {
        document.reference.delete();
      }
    } catch (e) {
      print('Error deleting room documents: $e');
      // Handle any errors that occur during the deletion process
    }
  }


  // Future<void> hangUp(BuildContext context,RTCVideoRenderer localVideo,RTCVideoRenderer remoteVideo) async {
  //   localStream!.getTracks().forEach((track) => track.stop());
  //   if (peerConnection != null) {
  //     await peerConnection!.close();
  //   }
  //   remoteStream!.dispose();
  //   localVideo.srcObject = null;
  //   remoteVideo.srcObject = null;
  //   localStream!.dispose();
  //   localVideo.dispose();
  //   remoteVideo.dispose();
  //   await clearFirestoreCollections();
  //   Navigator.of(context).pop();
  // }
  //
  // Future<void> clearFirestoreCollections() async {
  //   var db = FirebaseFirestore.instance;
  //   var roomRef = db.collection('rooms').doc(roomId);
  //   print("roomRef --> $roomRef");
  //   var collection = FirebaseFirestore.instance.collection('ActiveCallers');
  //   var snapshots = await collection.get();
  //   for (var doc in snapshots.docs) {
  //     await doc.reference.delete();
  //   }
  //   var collectionRoom = FirebaseFirestore.instance.collection('rooms');
  //   var snapshot = await collectionRoom.get();
  //   for (var doc in snapshot.docs) {
  //     await doc.reference.delete();
  //   }
  // }
  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };
    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state change: $state');
    };
    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state change: $state');
    };
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE connection state change: $state');
    };


    print("peerConnection?.onAddStream --> ${peerConnection?.onAddStream}");

    peerConnection?.onAddStream = (MediaStream stream) {
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
    };
  }
}
