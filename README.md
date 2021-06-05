# advanced_image

Flutter network image provider with caching and retry support

## Example

```
import 'package:advanced_image/provider.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(App());
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Advanced image example'),
        ),
        body: Center(
          child: Image(
            image: AdvancedNetworkImage(
              'https://i.imgur.com/Uschheg.jpeg',
              headers: {
                'X-Auth': 'bla-bla',
              },
              retryOptions: RetryOptions(
                  delayFactor: Duration(milliseconds: 100),
                  maxDelay: Duration(seconds: 10),
                  randomizationFactor: 0.2,
                  maxAttempts: 4),
            ),
          ),
        ),
      ),
    );
  }
}
```


