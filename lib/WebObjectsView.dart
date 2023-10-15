import 'dart:convert';

import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;


class WebObjectsView extends StatefulWidget {
  const WebObjectsView({Key? key}) : super(key: key);

  @override
  State<WebObjectsView> createState() => _WebObjectsViewState();
}

class _WebObjectsViewState extends State<WebObjectsView> {
  // Speech to text related
  stt.SpeechToText speech = stt.SpeechToText();
  bool isListening = false;
  String text = "";
  String text3DPrompt = "";
  double confidence = 1.0;

  // AR related
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;

  //String webObjectReference;
  ARNode? webObjectNode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ARView(
        onARViewCreated: onARViewCreated,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
          onPressed: _listen,
          child: Icon(isListening ? Icons.mic : Icons.mic_none)
      )
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    // 1
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    // 2
    this.arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: "triangle.png",
      showWorldOrigin: true,
      handleTaps: false,
    );
    // 3
    this.arObjectManager.onInitialize();
  }

  Future<void> displayObject(String glbURL) async {
    if (webObjectNode != null) {
      await arObjectManager.removeNode(webObjectNode!);
      webObjectNode = null;
    } else {
      var newNode = ARNode(
          type: NodeType.webGLB,
          uri: glbURL,
          scale: Vector3(0.2, 0.2, 0.2));
      bool? didAddWebNode = await arObjectManager.addNode(newNode);
      webObjectNode = (didAddWebNode!) ? newNode : null;
    }
  }

  void textToGLB(String text3DPrompt) async {
    print("hello i am inside textToGLB");
    var baseURL = "https://mirage-app-external-api-v7qy.mirage-app.zeet.app/";
    var apiEndpoint = "search-multimodal/";
    var apiURL = baseURL + apiEndpoint;
    try {
      print("i am inside the try block now");
      var url = Uri.parse(apiURL);

      // GraphQL parameters
      Map<String, dynamic> graphQLParams = {
        "query": """
        query {
          asset_types: ["3D"],
          name: "$text3DPrompt"
        }
      """
      };

      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(graphQLParams),
      );

      if (response.statusCode == 200) {
        print("response was successful: 200");
        print(response.body);

        // Decode the response body from JSON
        Map<String, dynamic> responseBody = json.decode(response.body);

        // Access the URL
        String glbURL = responseBody['results'][0]['link'];

        // Render object on phone
        print(glbURL);
        setState(() {
          // displayObject(glbURL+ '?raw=true');
          displayObject("https://multimodal.blob.core.windows.net/threed/8e1ae20d-51da-435d-899f-9386f7b7a21a.glb");
        });
      } else {
        print("response was unsuccessful: ${response.statusCode}");
        print(response);
      }
    } catch (e) {
      print("error");
      print(e.toString());
    }
  }

  void _listen() async {
    if (!isListening) {
      bool available = await speech.initialize();
      if (available) {
        setState(() => isListening = true);
        speech.listen(
          onResult: (val) => setState(() {
            text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => isListening = false);
      speech.stop();
      // call Mirage ML API here using the text prompt
      textToGLB(text3DPrompt = text);
      text = "";
    }
  }

}
