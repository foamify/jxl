import 'package:flutter/material.dart';
import 'package:flutter_jxl/flutter_jxl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // JxlImage.asset(
              //   'assets/testanim.jxl',
              // ),
              JxlImage.asset(
                'assets/testanim2.jxl',
                cropInfo:
                    const CropInfo(width: 100, height: 300, left: 10, top: 0),
              ),
              JxlImage.network(
                'https://raw.githubusercontent.com/libjxl/conformance/master/testcases/animation_icos4d/input.jxl',
              ),
              JxlImage.asset(
                'assets/testalpha.jxl',
              ),
              JxlImage.asset(
                'assets/jxlImage.jxl',
                key: const Key('jxlImage'),
              ),
              JxlImage.asset(
                'assets/testhdr.jxl',
                cropInfo:
                    const CropInfo(width: 1000, height: 1000, left: 10, top: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
