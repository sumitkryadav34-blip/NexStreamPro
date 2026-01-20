import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const NexStreamApp());

class NexStreamApp extends StatelessWidget {
  const NexStreamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Search Movies/Shows...", border: InputBorder.none),
              onSubmitted: (v) => setState(() {}),
            )
          : const Text("NEXSTREAM PRO", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.cyanAccent), 
            onPressed: () => setState(() { _isSearching = !_isSearching; if(!_isSearching) _searchController.clear(); })
          )
        ],
      ),
      body: ContentGrid(categoryIndex: _selectedIndex, searchQuery: _searchController.text),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() { _selectedIndex = index; _isSearching = false; }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: "Movies"),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: "TV Shows"),
        ],
      ),
    );
  }
}

class ContentGrid extends StatefulWidget {
  final int categoryIndex;
  final String searchQuery;
  const ContentGrid({super.key, required this.categoryIndex, required this.searchQuery});
  @override
  _ContentGridState createState() => _ContentGridState();
}

class _ContentGridState extends State<ContentGrid> {
  final String apiKey = "2bc6e3d99bcfccaaf493af0fe3916b47";
  List dataList = [];
  bool isLoading = true;

  @override
  void initState() { super.initState(); fetchData(); }

  @override
  void didUpdateWidget(ContentGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryIndex != widget.categoryIndex || oldWidget.searchQuery != widget.searchQuery) fetchData();
  }

  fetchData() async {
    setState(() => isLoading = true);
    String url = widget.searchQuery.isNotEmpty 
      ? "https://api.themoviedb.org/3/search/multi?api_key=$apiKey&query=${widget.searchQuery}"
      : (widget.categoryIndex == 0 ? "https://api.themoviedb.org/3/trending/movie/day?api_key=$apiKey" : "https://api.themoviedb.org/3/tv/popular?api_key=$apiKey");

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() { dataList = json.decode(response.body)['results'] ?? []; isLoading = false; });
    }
  }

  Future<void> downloadMovie(String id, String title) async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      String videoUrl = "https://vidsrc.to/embed/movie/$id"; 
      Directory? tempDir = await getExternalStorageDirectory();
      String fullPath = "${tempDir!.path}/$title.mp4";
      try {
        await Dio().download(videoUrl, fullPath);
        print("Downloaded to: $fullPath");
      } catch (e) {
        print("Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        var item = dataList[index];
        if (item['poster_path'] == null) return Container();
        String title = item['title'] ?? item['name'] ?? "Movie";
        return Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerPage(id: item['id'].toString(), isTv: widget.categoryIndex == 1))),
                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network("https://image.tmdb.org/t/p/w500${item['poster_path']}", fit: BoxFit.cover)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline, color: Colors.cyanAccent),
              onPressed: () => downloadMovie(item['id'].toString(), title),
            )
          ],
        );
      },
    );
  }
}

class PlayerPage extends StatelessWidget {
  final String id;
  final bool isTv;
  const PlayerPage({super.key, required this.id, required this.isTv});
  @override
  Widget build(BuildContext context) {
    String url = isTv ? "https://vidsrc.to/embed/tv/$id" : "https://vidsrc.to/embed/movie/$id";
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, allowsInlineMediaPlayback: true),
      ),
    );
  }
}
