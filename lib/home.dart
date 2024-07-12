import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pathnv/model/path.dart';
import 'package:process_run/process_run.dart';
import 'package:process_run/stdio.dart';
import 'package:yaru/yaru.dart';
import 'package:lucide_icons/lucide_icons.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> with TickerProviderStateMixin {
  static const int tabCount = 2;
  static const String envTabLabel = "Environment Variables";
  static const String shellTabLabel = "Shell Variables";

  List<Paths> shellPaths = [];
  List<Paths> envPaths = [];
  List<Paths> filteredShellPaths = [];
  List<Paths> filteredEnvPaths = [];
  bool isRefreshing = false;
  bool isSearching = false;
  String searchQuery = '';

  final TextEditingController _pathController = TextEditingController();
  late final TabController _tabController;
  late final String _shell;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabCount, vsync: this)
      ..addListener(_handleTabChange);
    _shell = Platform.environment['SHELL'] ?? 'sh';
    runShellCommand();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void runShellCommand() async {
    final result = await Process.run(_shell, ['-l', '-i', '-c', 'echo \$PATH']);

    final envPathsResult = Platform.environment['PATH'];

    if (envPathsResult != null) {
      final shellPathsResult = result.stdout
          .trim()
          .split(':')
          .where((path) => !envPathsResult.contains(path))
          .toList();

          
      setState(() {
        envPaths.clear();
        envPaths.addAll(envPathsResult.split(':').map((path) => Paths(path)));

        shellPaths.clear();
        shellPaths.addAll(shellPathsResult.map((path) => Paths(path)).cast<Paths>());

        filteredShellPaths.clear();
        filteredShellPaths.addAll(shellPaths);

        filteredEnvPaths.clear();
        filteredEnvPaths.addAll(envPaths);
        isRefreshing = false;
      });
    }
  }

  Map<String, List<String>> getShellConfigFiles(String home) {
    return {
      'bash': ['$home/.bashrc', '$home/.bash_profile', '$home/.profile'],
      'zsh': ['$home/.zshrc', '$home/.zprofile', '$home/.profile'],
      'fish': ['$home/.config/fish/config.fish', '$home/.profile'],
      'csh': ['$home/.cshrc', '$home/.profile'],
      'tcsh': ['$home/.tcshrc', '$home/.profile'],
      'ksh': ['$home/.kshrc', '$home/.profile'],
    };
  }

  void filterPaths(String query) {
    setState(() {
      searchQuery = query;

      if (query.isEmpty) {
        filteredShellPaths = List.from(shellPaths);
        filteredEnvPaths = List.from(envPaths);
      } else {
        if (_tabController.index == 1) {
          filteredEnvPaths = envPaths
              .where((path) =>
                  path.path.toLowerCase().contains(query.toLowerCase()))
              .toList();
        } else {
          filteredShellPaths = shellPaths
              .where((path) =>
                  path.path.toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
      }
    });
  }

  Future<void> addNewPath(String newPath) async {
    final home = Platform.environment['HOME'];
    if (home == null) {
      throw Exception('HOME environment variable not set');
    }

    final configFiles = getShellConfigFiles(home);
    final shellType = _shell.split('/').last;
    var shellConfigFile = '';

    if (shellType == 'bash' || shellType == 'zsh') {
      shellConfigFile = configFiles[shellType]![1];
    } else {
      shellConfigFile = configFiles[shellType]![0];
    }

    final file = File(shellConfigFile);
    await file.writeAsString('\nexport PATH="\$PATH:$newPath"\n',
        mode: FileMode.append);

    runShellCommand();
  }

  Future<void> deletePath(String pathToDelete) async {
    final home = Platform.environment['HOME'];
    if (home == null) {
      throw Exception('HOME environment variable not set');
    }

    final configFiles = getShellConfigFiles(home);
    final shellType = _shell.split('/').last;

    List<String> possibleConfigFiles =
        configFiles[shellType] ?? configFiles['bash']!;

    for (final configFile in possibleConfigFiles) {
      final file = File(configFile);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        bool pathFound = false;

        final updatedLines = lines.where((line) {
          if (line.trim().startsWith('export PATH=')) {
            final paths = line.split(':');
            if (paths.any((path) => path.contains(pathToDelete))) {
              pathFound = true;
              return false;
            }
          }
          return true;
        }).toList();

        if (pathFound) {
          await file.writeAsString(updatedLines.join('\n'));
          if (kDebugMode) {
            print('Updated PATH in $configFile');
          }
          runShellCommand();
          return;
        }
      }
    }
  }

  Future<void> editPath(String oldPath, String newPath) async {
    final home = Platform.environment['HOME'];
    if (home == null) {
      throw Exception('HOME environment variable not set');
    }

    final configFiles = getShellConfigFiles(home);
    final shellType = _shell.split('/').last;

    List<String> possibleConfigFiles =
        configFiles[shellType] ?? configFiles['bash']!;

    for (final configFile in possibleConfigFiles) {
      final file = File(configFile);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        bool pathFound = false;

        final updatedLines = lines.map((line) {
          if (line.trim().startsWith('export PATH=')) {
            if (line.contains(oldPath)) {
              pathFound = true;
              return line.replaceAll(oldPath, newPath);
            }
          }
          return line;
        }).toList();

        if (pathFound) {
          await file.writeAsString(updatedLines.join('\n'));
          if (kDebugMode) {
            print('Updated PATH in $configFile');
          }
          runShellCommand();
          return;
        }
      }
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: YaruWindowTitleBar(
        leading: _tabController.index == 1
            ? null
            : Center(
                child: YaruOptionButton(
                  child: const Icon(LucideIcons.plus),
                  onPressed: () {
                    addPathDialog(context);
                  },
                ),
              ),
        actions: [
          YaruSearchButton(
            icon: isSearching
                ? const Icon(LucideIcons.x)
                : const Icon(LucideIcons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                searchQuery = '';
                filteredShellPaths = List.from(shellPaths);
              });
            },
          ),
          const SizedBox(width: 8),
          YaruOptionButton(
            child: isRefreshing
                ? const YaruCircularProgressIndicator()
                : const Icon(LucideIcons.refreshCw),
            onPressed: () {
              setState(() {
                isRefreshing = true;
              });
              runShellCommand();
            },
          ),
          const SizedBox(width: 8),
          YaruPopupMenuButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            childPadding: EdgeInsets.zero,
            icon: const Icon(LucideIcons.menu),
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Text("Preferences"),
              ),
              const PopupMenuItem(
                child: Text("Keyboard Shortcuts"),
              ),
              PopupMenuItem(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    titlePadding: EdgeInsets.zero,
                    title: YaruDialogTitleBar(
                      isClosable: true,
                    ),
                    content: Text("Heeey"),
                  ),
                ),
                child: const Text("About PathNv"),
              ),
            ],
            child: const Text(""),
          )
        ],
        title: isSearching
            ? YaruSearchField(
                text: searchQuery,
                onChanged: filterPaths,
              )
            : const Text("PathNv"),
      ),
      body: Column(
        children: [
          YaruTabBar(
            tabController: _tabController,
            tabs: const [
              YaruTab(
                label: shellTabLabel,
                icon: Icon(LucideIcons.terminal),
              ),
              YaruTab(
                label: envTabLabel,
                icon: Icon(LucideIcons.settings),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(kYaruPagePadding),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.terminal),
                                const SizedBox(width: 8),
                                SelectableText(
                                  _shell.split('/').last,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text("(${filteredShellPaths.length})")
                          ],
                        ),
                        for (Paths path in filteredShellPaths) ...[
                          YaruTile(
                            style: YaruTileStyle.normal,
                            leading: path.isEditing
                                ? YaruIconButton(
                                    icon: const Icon(LucideIcons.folder),
                                    onPressed: () async {
                                      String? selectedDirectory =
                                          await FilePicker.platform
                                              .getDirectoryPath();
                                      if (selectedDirectory != null) {
                                        setState(() {
                                          _pathController.text =
                                              selectedDirectory;
                                        });
                                      }
                                    },
                                  )
                                : null,
                            trailing: Row(
                              children: [
                                if (path.isEditing) ...[
                                  YaruIconButton(
                                    icon: const Icon(LucideIcons.check),
                                    onPressed: () {
                                      editPathDialog(
                                          context, path, _pathController.text);
                                    },
                                  ),
                                  YaruIconButton(
                                    icon: const Icon(
                                      LucideIcons.x,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        path.isEditing = false;
                                      });
                                    },
                                  ),
                                ] else ...[
                                  YaruIconButton(
                                    icon: const Icon(LucideIcons.pencil),
                                    onPressed: () {
                                      setState(() {
                                        path.isEditing = true;
                                        _pathController.text = path.path;
                                      });
                                    },
                                  ),
                                  YaruIconButton(
                                    icon: const Icon(
                                      LucideIcons.trash,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      deletePathDialog(context, path);
                                    },
                                  ),
                                ],
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 26),
                            title: path.isEditing
                                ? YaruSearchField(
                                    controller: _pathController,
                                    onChanged: (value) {
                                      setState(() {
                                        // path.newPath = value;
                                        _pathController.text = value;
                                      });
                                    },
                                  )
                                : SelectableText(path.path),
                          ),
                          const Divider(),
                        ],
                      ],
                    )
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(kYaruPagePadding),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(LucideIcons.settings),
                                SizedBox(width: 8),
                                SelectableText(
                                  "Env",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text("(${filteredEnvPaths.length})")
                          ],
                        ),
                        for (Paths path in filteredEnvPaths) ...[
                          YaruTile(
                            style: YaruTileStyle.normal,
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 26),
                            title: SelectableText(path.path),
                          ),
                          const Divider(),
                        ],
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<dynamic> addPathDialog(BuildContext context) {
    TextEditingController pathController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        String newPath = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return SimpleDialog(
              contentPadding: const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 16.0),
              title: const Text("Add Path"),
              children: [
                YaruTile(
                  leading: YaruIconButton(
                    icon: const Icon(LucideIcons.folder),
                    onPressed: () async {
                      String? selectedDirectoryPath =
                          await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectoryPath != null) {
                        setState(() {
                          newPath = selectedDirectoryPath;
                          pathController.text = newPath;
                        });
                      }
                    },
                  ),
                  title: SizedBox(
                    width: 500,
                    child: YaruSearchField(
                      style: YaruSearchFieldStyle.filledOutlined,
                      radius: const Radius.circular(8),
                      hintText: "Enter path",
                      controller: pathController,
                      onChanged: (value) {
                        setState(() {
                          newPath = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        if (newPath.isNotEmpty) {
                          addNewPath(newPath);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Add"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      pathController.dispose();
    });
  }

  Future<dynamic> editPathDialog(
      BuildContext context, Paths path, String newPath) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Path"),
          content: Text(
              "Are you sure you want to change the path from:\n\n${path.path}\n\nto:\n\n$newPath"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  path.isEditing = false;
                });
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (newPath.isNotEmpty && newPath != path.path) {
                  editPath(path.path, newPath);
                  setState(() {
                    path.isEditing = false;
                    path.path = newPath;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> deletePathDialog(BuildContext context, Paths path) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Path"),
          content: Text(
              "Are you sure you want to delete this path?\n\n${path.path} "),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                if (path.path.isNotEmpty) {
                  deletePath(path.path);
                  Navigator.pop(context);
                }
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }
}
