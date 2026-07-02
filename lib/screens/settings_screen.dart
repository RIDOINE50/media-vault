import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/download_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        return Scaffold(
          backgroundColor: settings.darkMode ? Colors.grey[950] : Colors.grey[100],
          appBar: AppBar(
            backgroundColor: settings.darkMode ? Colors.grey[950] : Colors.grey[200],
            elevation: 0,
            title: Text(
              'Paramètres',
              style: TextStyle(
                color: settings.darkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: settings.darkMode ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // SECTION LECTURE
                _buildSection(
                  title: 'Lecture',
                  icon: Icons.play_circle_outline,
                  settings: settings,
                  children: [
                    _buildSliderSetting(
                      icon: Icons.volume_up,
                      title: 'Volume par défaut',
                      subtitle: '${(settings.defaultVolume * 100).toInt()}%',
                      value: settings.defaultVolume,
                      settings: settings,
                      onChanged: (value) => settings.setDefaultVolume(value),
                    ),
                    _buildSwitchSetting(
                      icon: Icons.repeat,
                      title: 'Lecture en boucle',
                      subtitle: 'Répéter la piste en cours',
                      value: settings.loopPlayback,
                      settings: settings,
                      onChanged: (value) => settings.setLoopPlayback(value),
                    ),
                    _buildSwitchSetting(
                      icon: Icons.shuffle,
                      title: 'Lecture aléatoire',
                      subtitle: 'Mélanger la bibliothèque',
                      value: settings.shufflePlayback,
                      settings: settings,
                      onChanged: (value) => settings.setShufflePlayback(value),
                    ),
                    _buildSwitchSetting(
                      icon: Icons.play_circle_outline,
                      title: 'Lecture en arrière-plan',
                      subtitle: 'Continuer quand app minimisée',
                      value: settings.backgroundPlayback,
                      settings: settings,
                      onChanged: (value) => settings.setBackgroundPlayback(value),
                    ),
                    _buildSwitchSetting(
                      icon: Icons.timer,
                      title: 'Minuterie d\'arrêt',
                      subtitle: 'Arrêter après un délai',
                      value: settings.sleepTimer,
                      settings: settings,
                      onChanged: (value) => settings.setSleepTimer(value),
                    ),
                  ],
                ),

                // SECTION TÉLÉCHARGEMENT
                _buildSection(
                  title: 'Téléchargement',
                  icon: Icons.download,
                  settings: settings,
                  children: [
                    _buildRadioSetting(
                      icon: Icons.graphic_eq,
                      title: 'Qualité audio',
                      subtitle: 'Qualité des fichiers téléchargés',
                      value: settings.audioQuality,
                      settings: settings,
                      options: const {
                        '128': '128 kbps',
                        '256': '256 kbps',
                        '320': '320 kbps (Meilleure)',
                      },
                      onChanged: (value) {
                        if (value != null) settings.setAudioQuality(value);
                      },
                    ),
                  ],
                ),

                // SECTION APPARENCE
                _buildSection(
                  title: 'Apparence',
                  icon: Icons.palette,
                  settings: settings,
                  children: [
                    _buildSwitchSetting(
                      icon: Icons.dark_mode,
                      title: 'Thème sombre',
                      subtitle: 'Interface en mode nuit',
                      value: settings.darkMode,
                      settings: settings,
                      onChanged: (value) => settings.setDarkMode(value),
                    ),
                  ],
                ),

                // SECTION STOCKAGE
                _buildSection(
                  title: 'Stockage',
                  icon: Icons.storage,
                  settings: settings,
                  children: [
                    _buildStorageCard(context, settings),
                  ],
                ),

                // SECTION À PROPOS
                _buildSection(
                  title: 'À propos',
                  icon: Icons.info,
                  settings: settings,
                  children: [
                    _buildSetting(
                      icon: Icons.tag,
                      title: 'Version de l\'app',
                      subtitle: 'v1.0.0',
                      settings: settings,
                      onTap: () {},
                    ),
                    _buildSetting(
                      icon: Icons.system_update,
                      title: 'Vérifier les mises à jour',
                      subtitle: 'Dernière vérification: Aujourd\'hui',
                      settings: settings,
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, double>> _calculateStorage() async {
    final downloadService = DownloadService();
    final files = await downloadService.getDownloadedFiles();
    
    double audioSize = 0;
    double videoSize = 0;
    
    for (var file in files) {
      try {
        final fileInfo = File(file.path);
        if (await fileInfo.exists()) {
          final size = await fileInfo.length();
          final sizeInMB = size / (1024 * 1024);
          
          if (file.isVideo) {
            videoSize += sizeInMB;
          } else {
            audioSize += sizeInMB;
          }
        }
      } catch (e) {
        print('Erreur lecture taille fichier: $e');
      }
    }
    
    return {
      'audio': audioSize,
      'video': videoSize,
      'total': audioSize + videoSize,
    };
  }

  String _formatSize(double sizeInMB) {
    if (sizeInMB < 1024) {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInMB / 1024).toStringAsFixed(2)} GB';
    }
  }

  Widget _buildStorageCard(BuildContext context, SettingsService settings) {
    return FutureBuilder<Map<String, double>>(
      future: _calculateStorage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur de calcul',
              style: TextStyle(color: Colors.red[400]),
            ),
          );
        }

        final storage = snapshot.data ?? {'audio': 0.0, 'video': 0.0, 'total': 0.0};
        final audioSize = storage['audio']!;
        final videoSize = storage['video']!;
        final totalSize = storage['total']!;
        
        const totalAvailable = 10.0 * 1024;
        final usedGB = totalSize / 1024;
        final totalGB = totalAvailable / 1024;
        final progressValue = (totalSize / totalAvailable).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: settings.darkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: settings.darkMode ? Colors.grey[800]! : Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Espace utilisé',
                    style: TextStyle(
                      color: settings.darkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${usedGB.toStringAsFixed(2)} GB / ${totalGB.toStringAsFixed(1)} GB',
                    style: TextStyle(
                      color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: settings.darkMode ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    settings.accentColor == 'blue' ? Colors.blue :
                    settings.accentColor == 'green' ? Colors.green :
                    settings.accentColor == 'red' ? Colors.red :
                    const Color(0xFF6200EE),
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.purple,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Audio (${_formatSize(audioSize)})',
                    style: TextStyle(color: settings.darkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Vidéo (${_formatSize(videoSize)})',
                    style: TextStyle(color: settings.darkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required SettingsService settings,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: settings.darkMode ? Colors.grey[400] : Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: settings.darkMode ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: settings.darkMode ? Colors.grey[800]! : Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required SettingsService settings,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (settings.accentColor == 'blue' ? Colors.blue :
                  settings.accentColor == 'green' ? Colors.green :
                  settings.accentColor == 'red' ? Colors.red :
                  const Color(0xFF6200EE)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: settings.accentColor == 'blue' ? Colors.blue :
                             settings.accentColor == 'green' ? Colors.green :
                             settings.accentColor == 'red' ? Colors.red :
                             const Color(0xFF6200EE), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: settings.darkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: settings.darkMode ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
      ),
      trailing: Icon(Icons.chevron_right, color: settings.darkMode ? Colors.grey[600] : Colors.grey[400], size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required SettingsService settings,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (settings.accentColor == 'blue' ? Colors.blue :
                  settings.accentColor == 'green' ? Colors.green :
                  settings.accentColor == 'red' ? Colors.red :
                  const Color(0xFF6200EE)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: settings.accentColor == 'blue' ? Colors.blue :
                             settings.accentColor == 'green' ? Colors.green :
                             settings.accentColor == 'red' ? Colors.red :
                             const Color(0xFF6200EE), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: settings.darkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: settings.darkMode ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: settings.accentColor == 'blue' ? Colors.blue :
                     settings.accentColor == 'green' ? Colors.green :
                     settings.accentColor == 'red' ? Colors.red :
                     const Color(0xFF6200EE),
      ),
    );
  }

  Widget _buildSliderSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required SettingsService settings,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (settings.accentColor == 'blue' ? Colors.blue :
                  settings.accentColor == 'green' ? Colors.green :
                  settings.accentColor == 'red' ? Colors.red :
                  const Color(0xFF6200EE)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: settings.accentColor == 'blue' ? Colors.blue :
                             settings.accentColor == 'green' ? Colors.green :
                             settings.accentColor == 'red' ? Colors.red :
                             const Color(0xFF6200EE), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: settings.darkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            activeColor: settings.accentColor == 'blue' ? Colors.blue :
                         settings.accentColor == 'green' ? Colors.green :
                         settings.accentColor == 'red' ? Colors.red :
                         const Color(0xFF6200EE),
            inactiveColor: settings.darkMode ? Colors.grey[700] : Colors.grey[300],
            onChanged: onChanged,
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: settings.darkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioSetting({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required SettingsService settings,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (settings.accentColor == 'blue' ? Colors.blue :
                      settings.accentColor == 'green' ? Colors.green :
                      settings.accentColor == 'red' ? Colors.red :
                      const Color(0xFF6200EE)).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: settings.accentColor == 'blue' ? Colors.blue :
                                 settings.accentColor == 'green' ? Colors.green :
                                 settings.accentColor == 'red' ? Colors.red :
                                 const Color(0xFF6200EE), size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: settings.darkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: settings.darkMode ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
          ),
        ),
        ...options.entries.map((entry) {
          final isSelected = value == entry.key;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 2),
            title: Text(
              entry.value,
              style: TextStyle(
                color: isSelected ? (settings.darkMode ? Colors.white : Colors.black87) : (settings.darkMode ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
            trailing: Radio<String>(
              value: entry.key,
              groupValue: value,
              onChanged: onChanged,
              activeColor: settings.accentColor == 'blue' ? Colors.blue :
                           settings.accentColor == 'green' ? Colors.green :
                           settings.accentColor == 'red' ? Colors.red :
                           const Color(0xFF6200EE),
            ),
            onTap: () => onChanged(entry.key),
          );
        }).toList(),
      ],
    );
  }
}