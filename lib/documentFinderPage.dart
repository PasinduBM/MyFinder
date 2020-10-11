import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:open_file/open_file.dart';

class DocumentFinder extends StatefulWidget {


  DocumentFinder({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _DocumentFinderState createState() => _DocumentFinderState();
}

class _DocumentFinderState extends State<DocumentFinder> {



  /////////////storage///////////////////////////////////////
  PermissionStatus storagePermission;
  String dirBaseStr;
  File currentFile;
  //////////////////////////////////////////////////////////////////////

  /////////////dynamic list /////////////////////////////////////////////
  //tempary pathStringList
  List<String> pathStrList = new List();
  //temparary documentLsist
  List<String> docNameList = new List();
  List<String> docContentList = new List();
  List<String> docPathList = new List();

  /////////////App states/////////////////////////////////////////////////
  bool _isEditting = false;
  bool _isNoDocFound = false;
  bool _isRefreshed = false;
  ////////////////////////////////////////////////////////////////////////

  /////////////search bar/////////////////////////////////////////////////
  TextEditingController _searchQueryController = TextEditingController();
  TextEditingController _descriptonTextController = TextEditingController();
  bool _isSearching = false;
  String searchQuery = "Search query";
  ///////////////////////////////////////////////////////////////////////


  @override
  void initState() {
    super.initState();
    getPermission().then((value) => {
      if(value.isGranted){
        initBaseDirectory().then((value2) => {
          if(value2.isNotEmpty){
            createDirectory('$dirBaseStr/MyFinder')
          }
        })
      }
    });

    print('init State finished');
  }

  ///////////////////////search field///////////////////////////////////////
  Widget _buildTitleBar(){
    if(_isEditting){
      return AppBar(
          leading: BackButton(
            onPressed: (){setState(() {
              _isEditting = false;
            });},
          ),
          title: _buildEditingTitle(context),

      );
    }else{
      return AppBar(
          leading: _isSearching ? const BackButton() : Container(),
          title: _isSearching ? _buildSearchField() : _buildTitle(context),
          actions: _buildActions());
    }

  }
  Widget _buildBody(){
    if(_isEditting){
      return _buildTextEditor();
    }else{
      return _buildListView();
    }
  }
  Widget _buildTextEditor(){
    return Container(
      padding: EdgeInsets.all(10),
      child: TextField(
        controller: _descriptonTextController,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        autofocus: true,
        decoration: InputDecoration(
          hintText: "Add Description Here...",
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.blueGrey),
        ),
        style: TextStyle(color: Colors.black87, fontSize: 18.0),
        onChanged: (query) => updateSearchQuery(query),
      ),
    );
  }
  Widget _buildListView(){
    return new ListView.builder(
        itemCount: docContentList.length,
        itemBuilder: (BuildContext ctxt, int index) {
          return new Card(
            child: ListTile(
              title:  RichText(text:TextSpan(
                children: highlightOccurrences(docNameList[index], _searchQueryController.value.text),
                style: TextStyle(color: Colors.black87),
              )),
              subtitle: RichText(text:TextSpan(
                children: highlightOccurrences(docContentList[index], _searchQueryController.value.text),
                style: TextStyle(color: Colors.grey),
              )),//Text(docContentList[index]),
              // trailing: Icon(Icons.more_vert),
              onTap: ()=> openDocEdit(docPathList[index],docNameList[index]),
            ),
          );
        });
  }
  Widget _buildFloatingButton(){

    if(_isNoDocFound){
      return FloatingActionButton(
        onPressed: openNewDoc,
        tooltip: 'Create a New Note',
        child: Icon(Icons.add),
      );
    }
    if(_isEditting){
      return FloatingActionButton(
        onPressed: saveContent,
        tooltip: 'Refresh files',
        child: Icon(Icons.save),
      );
    }else{
      return FloatingActionButton(
        onPressed: refreshPaths,
        tooltip: 'Save Description',
        child: Icon(Icons.refresh),
      );
    }

  }
  Widget _buildSearchField() {
    return TextField(
      controller: _searchQueryController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: "Search Data...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white30),
      ),
      style: TextStyle(color: Colors.white, fontSize: 16.0),
      onChanged: (query) => updateSearchQuery(query),
    );
  }
  Widget _buildTitle(BuildContext context) {
    return new Text("MyFinder");
  }
  Widget _buildEditingTitle(BuildContext context) {
    return new Text(_searchQueryController.value.text);
  }

  List<Widget> _buildActions() {
    if (_isSearching) {
      return <Widget>[
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            if (_searchQueryController == null ||
                _searchQueryController.text.isEmpty) {
              Navigator.pop(context);
              return;
            }
            _clearSearchQuery();
          },
        ),
      ];
    }

    return <Widget>[
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: ()=>_startSearch(),
      ),
    ];
  }
  void _clearSearchQuery() {
    setState(() {
      _searchQueryController.clear();
      _isNoDocFound = false;
      updateSearchQuery("");
    });
  }
  void _startSearch(){
    ModalRoute.of(context)
        .addLocalHistoryEntry(LocalHistoryEntry(onRemove: _stopSearching));
    if(storagePermission.isDenied){
      getPermission();
    }else{
      if(!_isRefreshed){
        refreshPaths();
        _isRefreshed=true;
        findFiles();
        setState(() {

        });
      }
      setState(() {
        _isSearching = true;
      });
      findFiles();
      setState(() {

      });
    }

  }

  void updateSearchQuery(String newQuery) {
    setState(() {
      searchQuery = newQuery;
      if(newQuery.isEmpty){
        _isNoDocFound = false;

      }
    });
    findFiles();

  }

  void _stopSearching() {
    _clearSearchQuery();

    setState(() {
      _isSearching = false;
    });
  }
  //////////////////////////////////////////////////////////////////////////
  ///////////////////////dynamic list///////////////////////////////////////
  @override
  void dispose() {
    // controller.removeListener(_scrollListener);
    super.dispose();
  }


  void findFiles(){
    docPathList.clear();
    docContentList.clear();
    docNameList.clear();
    setState(() {

    });
    pathStrList.forEach((path) {

      if(path.split('/').last.startsWith(_searchQueryController.value.text)){
        setState(() {
          docNameList.add(path.split('/').last.split('.').first);
          File doc = new File(path);
          String content = doc.readAsStringSync();
          if(content.length>50){
            docContentList.add(content.substring(0,50));
          }else{
            docContentList.add(content);
          }
          docPathList.add(path);
        });
      }

    });
    if(docNameList.length<1 && _searchQueryController.value.text.isNotEmpty && !_isEditting){
      _isNoDocFound=true;
    }else{
      _isNoDocFound = false;
    }
    setState(() {

    });

  }

  /////////////////////refresh paths ////////////////////////////////////////
  void refreshPaths() async{
    if(storagePermission.isGranted){
      if(dirBaseStr.isEmpty){
        initBaseDirectory();
        refreshPaths();
      }else{
        print(dirBaseStr);
        var dir = new Directory('$dirBaseStr/MyFinder');
        bool ok =  await dir.exists();
        if(ok){
          pathStrList.clear();
          print("|||| Exist ||||");
          dir.list(recursive: true, followLinks: false)
              .listen((FileSystemEntity entity) {
            print(entity.path);
            pathStrList.add(entity.path);
          });
        }else{
          print("Don't Exist");
          // createDirectory('$dirBaseStr/MyFinder');
        }
        setState(() {

        });
      }

    }else{
      getPermission();
    }

  }
  ////////////////////////////////////////////////////////////////////////////
  ////////////////Save content///////////////////////////////////////////////
  void openDocEdit(String path,String name){
    _searchQueryController.text = name;
    currentFile = new File(path);
    _descriptonTextController.text = currentFile.readAsStringSync();
    _isEditting = true;
    setState(() {

    });

  }

  void openNewDoc(){
    currentFile = new File('$dirBaseStr/MyFinder/${_searchQueryController.value.text}.txt');
    _isEditting = true;
    _isNoDocFound = false;
    _descriptonTextController.text = '';
    setState(() {

    });
  }

  void saveContent(){
    currentFile.writeAsStringSync(_descriptonTextController.value.text);

    setState(() {

      refreshPaths();
      _isSearching = false;
      _isNoDocFound=false;
      _isEditting = false;
      _searchQueryController.text='';
      _descriptonTextController.text = '';
      setState(() {

      });
    });

  }

  //////////////////create MyFinder folder////////////////////////////////////
  Future<void> createDirectory(String path) async{
    print('creating directory');
    new Directory(path).create()
        .then((Directory directory) {
      print(directory.path);
    });
    setState(() {

    });
  }
  ///////////////////////////////////////////////////////////////////////////
  //////////////////init base directory/////////////////////////////////////
  Future<String> initBaseDirectory() async{
    dirBaseStr = await ExtStorage.getExternalStorageDirectory();
    return dirBaseStr;
  }
  ///////////////////get storage permission//////////////////////////////////
  Future<PermissionStatus> getPermission() async{
    print("getting permission");
    storagePermission = await Permission.storage.request();
    return storagePermission;

  }

  ////////////////highlight text/////////////////////////////////////////////
  List<TextSpan> highlightOccurrences(String source, String query) {
    if (query == null || query.isEmpty || !source.toLowerCase().contains(query.toLowerCase())) {
      return [ TextSpan(text: source) ];
    }
    final matches = query.toLowerCase().allMatches(source.toLowerCase());

    int lastMatchEnd = 0;

    final List<TextSpan> children = [];
    for (var i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);

      if (match.start != lastMatchEnd) {
        children.add(TextSpan(
          text: source.substring(lastMatchEnd, match.start),
        ));
      }

      children.add(TextSpan(
        text: source.substring(match.start, match.end),
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      ));

      if (i == matches.length - 1 && match.end != source.length) {
        children.add(TextSpan(
          text: source.substring(match.end, source.length),
        ));
      }

      lastMatchEnd = match.end;
    }
    return children;
  }
  /////////////////////////////////////////////////////////////////////////////////

  /////////////open file//////////////////////////////////////////////////
  void openFile(String path) async{
    await OpenFile.open(path);
    print("file open");
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: _buildTitleBar(),
      body: _buildBody(),

      floatingActionButton: _buildFloatingButton(),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
