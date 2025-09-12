  // 初始化文件服务
  final fileService = FileService();
  
  // 初始化文件传输模型
  final fileTransferModel = FileTransferModel(fileService: fileService);
  
  // 初始化设置模型
  final settingsModel = SettingsModel();
  
  runApp(
    MultiProvider(
      providers: [
        // 注入 FileService 到 FileTransferModel
        ChangeNotifierProvider.value(value: fileTransferModel),
        ChangeNotifierProvider.value(value: settingsModel),
      ],
      child: MyApp(),
    ),
  );
}