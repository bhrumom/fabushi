class LocalProject {
  final String name;
  final String path;
  final DateTime updatedAt;
  final bool isExternal;

  const LocalProject({
    required this.name,
    required this.path,
    required this.updatedAt,
    this.isExternal = false,
  });
}

class ProjectService {
  ProjectService._();
  static final ProjectService instance = ProjectService._();

  Future<List<LocalProject>> listProjects() async => const [];

  Future<LocalProject> createProject(String name) async {
    return LocalProject(name: name, path: name, updatedAt: DateTime.now());
  }

  Future<LocalProject> addProjectFromFolder(String folderPath) async {
    return LocalProject(
      name: folderPath,
      path: folderPath,
      updatedAt: DateTime.now(),
      isExternal: true,
    );
  }

  Future<void> deleteProject(String name) async {}
}
