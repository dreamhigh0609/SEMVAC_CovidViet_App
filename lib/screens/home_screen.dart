import 'dart:convert' show json;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider/push_notification.dart';
import '../provider/badge_provider.dart';
import '../widget/article_item_widget.dart';
import '../config/color.dart';
import '../model/article_model.dart';
import '../service/api.dart';
import '../widget/loading.dart';
import '../widget/appbar.dart';
import 'article_screen.dart';
import './article_screen_by_id.dart';

Future<void> onBackgroundMessageReceived(RemoteMessage message) async {
  if (message.notification != null) {
    var sentTime = message.sentTime;
    var data = message.data;
    List<Map> nfList = [];
    int prevBadgeCounts = 0;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    // prefs.clear();
    String prevListStr = prefs.getString('nfList');
    prevBadgeCounts = prefs.getInt('badgeCounts');
    if (prevBadgeCounts == null)
      prevBadgeCounts = 1;
    else
      prevBadgeCounts++;

    if (prevListStr != null) {
      var prevList = json.decode(prevListStr);
      nfList = List<Map>.from(prevList);
    }
    nfList.add(data);
    print(json.encode(nfList));
    await prefs.setInt('badgeCounts', prevBadgeCounts);
    await prefs.setString('nfList', json.encode(nfList));
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Service _service = new Service();
  Future<List<Article>> _getArticles;
  bool _isInForeground = true;

  @override
  void initState() {
    getMessage(context);
    _getArticles = getArticles(context);
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    _isInForeground = state == AppLifecycleState.resumed;
    if (_isInForeground) {
      int prevBadgeCounts = 0;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      prevBadgeCounts = prefs.getInt('badgeCounts');
      if (prevBadgeCounts != null)
        Provider.of<BadgeCounter>(context, listen: false)
            .setCounts(prevBadgeCounts);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<List<Article>> getArticles(context) async {
    var result = await _service.getArticleList();
    return result;
  }

  void getMessage(context) async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.notification != null) {
        var sentTime = message.sentTime;
        var data = message.data;
        List<Map> nfList = [];
        int prevBadgeCounts = 0;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        // prefs.clear();

        String prevListStr = prefs.getString('nfList');
        prevBadgeCounts = prefs.getInt('badgeCounts');
        await prefs.reload();
        if (prevBadgeCounts == null)
          prevBadgeCounts = 1;
        else
          prevBadgeCounts++;

        if (prevListStr != null) {
          var prevList = json.decode(prevListStr);
          nfList = List<Map>.from(prevList);
        }

        nfList.add(data);
        print(json.encode(nfList));
        prefs.setString('nfList', json.encode(nfList));
        prefs.setInt('badgeCounts', prevBadgeCounts);
        Provider.of<BadgeCounter>(context, listen: false)
            .setCounts(prevBadgeCounts);

        // Provider.of<PushNotification>(context, listen: false)
        //     .setNotificationData(
        //   data["article_id"],
        //   data["text"],
        //   data["type"],
        //   sentTime,
        // );
        // Provider.of<BadgeCounter>(context, listen: false).increment();
        // print(Provider.of<PushNotification>(context, listen: false).getText);
        // print(
        //     Provider.of<PushNotification>(context, listen: false).getSentTime);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (message.notification != null) {
        var sentTime = message.sentTime;
        var data = message.data;
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        String prevListStr = prefs.getString('nfList');
        List<Map> nfList = [];
        if (prevListStr != null) {
          var prevList = json.decode(prevListStr);
          nfList = List<Map>.from(prevList);
        }
        nfList.add(data);
        prefs.setString('nfList', json.encode(nfList));
        Provider.of<PushNotification>(context, listen: false)
            .setNotificationData(
          data["article_id"],
          data["text"],
          data["type"],
          sentTime,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleScreenById(
              id: data["article_id"],
            ),
          ),
        );
      }
    });
    FirebaseMessaging.onBackgroundMessage(onBackgroundMessageReceived);
  }

  Widget body(List<Article> data) {
    return Container(
      child: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(left: 5, top: 2, right: 5),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArticleScreen(
                      item: data[index],
                    ),
                  ),
                );
              },
              child: ArticleItemWidget(
                item: data[index],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var mq = MediaQuery.of(context).size;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: appBackground,
      appBar: appBar(context),
      body: LayoutBuilder(
        builder: (context, constraint) {
          return FractionallySizedBox(
            widthFactor: 1.0,
            child: FutureBuilder<List<Article>>(
              future: _getArticles,
              builder: (BuildContext context,
                  AsyncSnapshot<List<Article>> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.active:
                  case ConnectionState.waiting:
                    return Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: mq.height * 0.1,
                            ),
                            kLoadingWidget(context),
                          ],
                        ),
                      ),
                    );
                  case ConnectionState.done:
                  default:
                    if (snapshot.hasError || snapshot.data == null) {
                      return Container(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: mq.height * 0.1,
                              ),
                              kLoadingWidget(context),
                            ],
                          ),
                        ),
                      );
                    } else {
                      return body(snapshot.data);
                    }
                }
              },
            ),
          );
        },
      ),
    );
  }
}
