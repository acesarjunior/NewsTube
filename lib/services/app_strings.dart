import 'package:flutter/widgets.dart';

class AppStrings {
  final String languageCode;
  const AppStrings(this.languageCode);

  static const supportedLanguageCodes = <String>['en', 'pt', 'fr', 'de', 'it', 'cs', 'es', 'ja'];

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
    Locale('fr'),
    Locale('de'),
    Locale('it'),
    Locale('cs'),
    Locale('es'),
    Locale('ja'),
  ];

  static const languageLabels = <String, String>{
    'en': 'English',
    'pt': 'Português',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'cs': 'Čeština',
    'es': 'Español',
    'ja': '日本語',
  };

  static AppStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppStrings(locale.languageCode);
  }

  static String normalizeLanguageCode(String? code) {
    final c = (code ?? '').trim().toLowerCase();
    if (supportedLanguageCodes.contains(c)) return c;
    return 'en';
  }

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_title': 'NewsTube',
      'search': 'Search',
      'favorites': 'Favorites',
      'theme': 'Theme',
      'language': 'Language',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'System',
      'search_videos_channels': 'Search videos and channels',
      'type_search': 'Type your search',
      'reload': 'Reload',
      'copy': 'Copy',
      'copied': 'Text copied.',
      'transcript': 'Transcript',
      'loading': 'Loading...',
      'searching_captions': 'Searching captions...',
      'failed': 'Failed',
      'translate': 'Translate',
      'translation_done': 'Translation completed',
      'translation_failed': 'Could not translate the text right now.',
      'translation_language': 'Translation language',
      'choose_once_auto': 'Choose once; translation will then be automatic',
      'view_original': 'View original',
      'view_translation': 'View translation',
      'grammar_fix': 'Fix grammar',
      'grammar_fixed': 'Grammar corrected.',
      'grammar_failed': 'Could not correct grammar right now.',
      'correcting_grammar': 'Correcting grammar...',
      'article': 'Article',
      'channel': 'Channel',
      'channels': 'Channels',
      'videos': 'Videos',
      'favorite_channel': 'Favorite channel',
      'remove_favorite': 'Remove favorite',
      'read': 'Read',
      'no_favorites': 'No favorites yet.',
      'search_channels': 'Search channels',
      'enter_channel_name': 'Enter channel name',
      'no_channel_found': 'No channel found.',
      'no_video_found_channel': 'No videos found for this channel.',
      'load_more_failed': 'Could not load more videos',
      'error': 'Error',
      'captions_only_note': 'Note: this mode uses only the video’s own captions. If the video has no captions, text cannot be generated without offline transcription.',
      'translate_banner': 'The caption seems to be in “{caption}”, different from the system language (“{system}”). Do you want to translate it?',
      'dont_remind': 'Don’t remind',
      'status_caption': 'Caption: {lang}',
      'no_favorite_channels': 'No channels in favorites.',
      'render_error': 'Error rendering interface.',
      'fatal_start_error': 'Critical failure while starting the application.',
    },
    'pt': {
      'app_title': 'NewsTube',
      'search': 'Buscar',
      'favorites': 'Favoritos',
      'theme': 'Tema',
      'language': 'Idioma',
      'theme_light': 'Claro',
      'theme_dark': 'Escuro',
      'theme_system': 'Sistema',
      'search_videos_channels': 'Buscar vídeos e canais',
      'type_search': 'Digite sua busca',
      'reload': 'Recarregar',
      'copy': 'Copiar',
      'copied': 'Texto copiado.',
      'transcript': 'Transcrição',
      'loading': 'Carregando...',
      'searching_captions': 'Buscando legendas...',
      'failed': 'Falhou',
      'translate': 'Traduzir',
      'translation_done': 'Tradução concluída',
      'translation_failed': 'Não foi possível traduzir o texto agora.',
      'translation_language': 'Idioma da tradução',
      'choose_once_auto': 'Escolha uma vez; depois a tradução será automática',
      'view_original': 'Ver original',
      'view_translation': 'Ver tradução',
      'grammar_fix': 'Corrigir gramática',
      'grammar_fixed': 'Gramática corrigida.',
      'grammar_failed': 'Não foi possível corrigir a gramática agora.',
      'correcting_grammar': 'Corrigindo gramática...',
      'article': 'Artigo',
      'channel': 'Canal',
      'channels': 'Canais',
      'videos': 'Vídeos',
      'favorite_channel': 'Canal favorito',
      'remove_favorite': 'Remover favorito',
      'read': 'Lido',
      'no_favorites': 'Nenhum favorito ainda.',
      'search_channels': 'Buscar canais',
      'enter_channel_name': 'Digite o nome do canal',
      'no_channel_found': 'Nenhum canal encontrado.',
      'no_video_found_channel': 'Nenhum vídeo encontrado para este canal.',
      'load_more_failed': 'Não foi possível carregar mais vídeos',
      'error': 'Erro',
      'captions_only_note': 'Observação: este modo usa apenas legendas do próprio vídeo. Se o vídeo não tiver legendas, não é possível gerar texto sem transcrição offline.',
      'translate_banner': 'A legenda parece estar em “{caption}”, diferente do idioma do sistema (“{system}”). Deseja traduzir?',
      'dont_remind': 'Não lembrar',
      'status_caption': 'Legenda: {lang}',
      'no_favorite_channels': 'Nenhum canal nos favoritos.',
      'render_error': 'Erro ao renderizar a interface.',
      'fatal_start_error': 'Falha crítica ao iniciar o aplicativo.',
    },
    'fr': {
      'app_title': 'NewsTube', 'search': 'Rechercher', 'favorites': 'Favoris', 'theme': 'Thème', 'language': 'Langue', 'theme_light': 'Clair', 'theme_dark': 'Sombre', 'theme_system': 'Système', 'search_videos_channels': 'Rechercher des vidéos et des chaînes', 'type_search': 'Saisissez votre recherche', 'reload': 'Recharger', 'copy': 'Copier', 'copied': 'Texte copié.', 'transcript': 'Transcription', 'loading': 'Chargement...', 'searching_captions': 'Recherche des sous-titres...', 'failed': 'Échec', 'translate': 'Traduire', 'translation_done': 'Traduction terminée', 'translation_failed': 'Impossible de traduire le texte pour le moment.', 'translation_language': 'Langue de traduction', 'choose_once_auto': 'Choisissez une fois ; ensuite la traduction sera automatique', 'view_original': 'Voir l’original', 'view_translation': 'Voir la traduction', 'grammar_fix': 'Corriger la grammaire', 'grammar_fixed': 'Grammaire corrigée.', 'grammar_failed': 'Impossible de corriger la grammaire pour le moment.', 'correcting_grammar': 'Correction de la grammaire...', 'article': 'Article', 'channel': 'Chaîne', 'channels': 'Chaînes', 'videos': 'Vidéos', 'favorite_channel': 'Chaîne favorite', 'remove_favorite': 'Retirer des favoris', 'read': 'Lu', 'no_favorites': 'Aucun favori pour le moment.', 'search_channels': 'Rechercher des chaînes', 'enter_channel_name': 'Entrez le nom de la chaîne', 'no_channel_found': 'Aucune chaîne trouvée.', 'no_video_found_channel': 'Aucune vidéo trouvée pour cette chaîne.', 'load_more_failed': 'Impossible de charger plus de vidéos', 'error': 'Erreur', 'captions_only_note': 'Remarque : ce mode utilise uniquement les sous-titres de la vidéo. Si la vidéo n’a pas de sous-titres, le texte ne peut pas être généré sans transcription hors ligne.', 'translate_banner': 'Les sous-titres semblent être en « {caption} », différent de la langue du système (« {system} »). Voulez-vous traduire ?', 'dont_remind': 'Ne plus rappeler', 'status_caption': 'Sous-titre : {lang}', 'no_favorite_channels': 'Aucune chaîne dans les favoris.', 'render_error': 'Erreur lors du rendu de l’interface.', 'fatal_start_error': 'Échec critique au démarrage de l’application.'
    },
    'de': {
      'app_title': 'NewsTube', 'search': 'Suchen', 'favorites': 'Favoriten', 'theme': 'Thema', 'language': 'Sprache', 'theme_light': 'Hell', 'theme_dark': 'Dunkel', 'theme_system': 'System', 'search_videos_channels': 'Videos und Kanäle suchen', 'type_search': 'Suche eingeben', 'reload': 'Neu laden', 'copy': 'Kopieren', 'copied': 'Text kopiert.', 'transcript': 'Transkript', 'loading': 'Wird geladen...', 'searching_captions': 'Untertitel werden gesucht...', 'failed': 'Fehlgeschlagen', 'translate': 'Übersetzen', 'translation_done': 'Übersetzung abgeschlossen', 'translation_failed': 'Der Text konnte momentan nicht übersetzt werden.', 'translation_language': 'Übersetzungssprache', 'choose_once_auto': 'Einmal auswählen; danach erfolgt die Übersetzung automatisch', 'view_original': 'Original anzeigen', 'view_translation': 'Übersetzung anzeigen', 'grammar_fix': 'Grammatik korrigieren', 'grammar_fixed': 'Grammatik korrigiert.', 'grammar_failed': 'Die Grammatik konnte momentan nicht korrigiert werden.', 'correcting_grammar': 'Grammatik wird korrigiert...', 'article': 'Artikel', 'channel': 'Kanal', 'channels': 'Kanäle', 'videos': 'Videos', 'favorite_channel': 'Favorisierter Kanal', 'remove_favorite': 'Favorit entfernen', 'read': 'Gelesen', 'no_favorites': 'Noch keine Favoriten.', 'search_channels': 'Kanäle suchen', 'enter_channel_name': 'Kanalnamen eingeben', 'no_channel_found': 'Kein Kanal gefunden.', 'no_video_found_channel': 'Für diesen Kanal wurden keine Videos gefunden.', 'load_more_failed': 'Weitere Videos konnten nicht geladen werden', 'error': 'Fehler', 'captions_only_note': 'Hinweis: Dieser Modus verwendet nur die Untertitel des Videos selbst. Wenn das Video keine Untertitel hat, kann ohne Offline-Transkription kein Text erzeugt werden.', 'translate_banner': 'Die Untertitel scheinen in „{caption}“ zu sein, was sich von der Systemsprache („{system}“) unterscheidet. Möchten Sie übersetzen?', 'dont_remind': 'Nicht erinnern', 'status_caption': 'Untertitel: {lang}', 'no_favorite_channels': 'Keine Kanäle in den Favoriten.', 'render_error': 'Fehler beim Rendern der Oberfläche.', 'fatal_start_error': 'Kritischer Fehler beim Starten der Anwendung.'
    },
    'it': {
      'app_title': 'NewsTube', 'search': 'Cerca', 'favorites': 'Preferiti', 'theme': 'Tema', 'language': 'Lingua', 'theme_light': 'Chiaro', 'theme_dark': 'Scuro', 'theme_system': 'Sistema', 'search_videos_channels': 'Cerca video e canali', 'type_search': 'Digita la tua ricerca', 'reload': 'Ricarica', 'copy': 'Copia', 'copied': 'Testo copiato.', 'transcript': 'Trascrizione', 'loading': 'Caricamento...', 'searching_captions': 'Ricerca dei sottotitoli...', 'failed': 'Operazione non riuscita', 'translate': 'Traduci', 'translation_done': 'Traduzione completata', 'translation_failed': 'Impossibile tradurre il testo in questo momento.', 'translation_language': 'Lingua di traduzione', 'choose_once_auto': 'Scegli una volta; poi la traduzione sarà automatica', 'view_original': 'Vedi originale', 'view_translation': 'Vedi traduzione', 'grammar_fix': 'Correggi grammatica', 'grammar_fixed': 'Grammatica corretta.', 'grammar_failed': 'Impossibile correggere la grammatica in questo momento.', 'correcting_grammar': 'Correzione della grammatica...', 'article': 'Articolo', 'channel': 'Canale', 'channels': 'Canali', 'videos': 'Video', 'favorite_channel': 'Canale preferito', 'remove_favorite': 'Rimuovi dai preferiti', 'read': 'Letto', 'no_favorites': 'Nessun preferito per ora.', 'search_channels': 'Cerca canali', 'enter_channel_name': 'Inserisci il nome del canale', 'no_channel_found': 'Nessun canale trovato.', 'no_video_found_channel': 'Nessun video trovato per questo canale.', 'load_more_failed': 'Impossibile caricare altri video', 'error': 'Errore', 'captions_only_note': 'Nota: questa modalità usa solo i sottotitoli del video. Se il video non ha sottotitoli, non è possibile generare il testo senza trascrizione offline.', 'translate_banner': 'I sottotitoli sembrano essere in “{caption}”, diversi dalla lingua di sistema (“{system}”). Vuoi tradurre?', 'dont_remind': 'Non ricordare', 'status_caption': 'Sottotitolo: {lang}', 'no_favorite_channels': 'Nessun canale nei preferiti.', 'render_error': 'Errore durante il rendering dell’interfaccia.', 'fatal_start_error': 'Errore critico all’avvio dell’applicazione.'
    },
    'cs': {
      'app_title': 'NewsTube', 'search': 'Hledat', 'favorites': 'Oblíbené', 'theme': 'Motiv', 'language': 'Jazyk', 'theme_light': 'Světlý', 'theme_dark': 'Tmavý', 'theme_system': 'Systém', 'search_videos_channels': 'Hledat videa a kanály', 'type_search': 'Zadejte hledání', 'reload': 'Načíst znovu', 'copy': 'Kopírovat', 'copied': 'Text zkopírován.', 'transcript': 'Přepis', 'loading': 'Načítání...', 'searching_captions': 'Hledají se titulky...', 'failed': 'Selhalo', 'translate': 'Přeložit', 'translation_done': 'Překlad dokončen', 'translation_failed': 'Text se teď nepodařilo přeložit.', 'translation_language': 'Jazyk překladu', 'choose_once_auto': 'Vyberte jednou; poté bude překlad automatický', 'view_original': 'Zobrazit originál', 'view_translation': 'Zobrazit překlad', 'grammar_fix': 'Opravit gramatiku', 'grammar_fixed': 'Gramatika opravena.', 'grammar_failed': 'Gramatiku se teď nepodařilo opravit.', 'correcting_grammar': 'Oprava gramatiky...', 'article': 'Článek', 'channel': 'Kanál', 'channels': 'Kanály', 'videos': 'Videa', 'favorite_channel': 'Oblíbený kanál', 'remove_favorite': 'Odebrat z oblíbených', 'read': 'Přečteno', 'no_favorites': 'Zatím žádné oblíbené.', 'search_channels': 'Hledat kanály', 'enter_channel_name': 'Zadejte název kanálu', 'no_channel_found': 'Nebyl nalezen žádný kanál.', 'no_video_found_channel': 'Pro tento kanál nebyla nalezena žádná videa.', 'load_more_failed': 'Nepodařilo se načíst další videa', 'error': 'Chyba', 'captions_only_note': 'Poznámka: tento režim používá pouze titulky samotného videa. Pokud video nemá titulky, bez offline přepisu nelze vytvořit text.', 'translate_banner': 'Titulky zřejmě jsou v jazyce „{caption}“, což se liší od jazyka systému („{system}“). Chcete přeložit?', 'dont_remind': 'Nepřipomínat', 'status_caption': 'Titulky: {lang}', 'no_favorite_channels': 'V oblíbených nejsou žádné kanály.', 'render_error': 'Chyba při vykreslování rozhraní.', 'fatal_start_error': 'Kritické selhání při spuštění aplikace.'
    },
    'es': {
      'app_title': 'NewsTube', 'search': 'Buscar', 'favorites': 'Favoritos', 'theme': 'Tema', 'language': 'Idioma', 'theme_light': 'Claro', 'theme_dark': 'Oscuro', 'theme_system': 'Sistema', 'search_videos_channels': 'Buscar videos y canales', 'type_search': 'Escribe tu búsqueda', 'reload': 'Recargar', 'copy': 'Copiar', 'copied': 'Texto copiado.', 'transcript': 'Transcripción', 'loading': 'Cargando...', 'searching_captions': 'Buscando subtítulos...', 'failed': 'Error', 'translate': 'Traducir', 'translation_done': 'Traducción completada', 'translation_failed': 'No se pudo traducir el texto ahora.', 'translation_language': 'Idioma de traducción', 'choose_once_auto': 'Elige una vez; después la traducción será automática', 'view_original': 'Ver original', 'view_translation': 'Ver traducción', 'grammar_fix': 'Corregir gramática', 'grammar_fixed': 'Gramática corregida.', 'grammar_failed': 'No se pudo corregir la gramática ahora.', 'correcting_grammar': 'Corrigiendo gramática...', 'article': 'Artículo', 'channel': 'Canal', 'channels': 'Canales', 'videos': 'Videos', 'favorite_channel': 'Canal favorito', 'remove_favorite': 'Quitar favorito', 'read': 'Leído', 'no_favorites': 'Todavía no hay favoritos.', 'search_channels': 'Buscar canales', 'enter_channel_name': 'Escribe el nombre del canal', 'no_channel_found': 'No se encontró ningún canal.', 'no_video_found_channel': 'No se encontraron videos para este canal.', 'load_more_failed': 'No se pudieron cargar más videos', 'error': 'Error', 'captions_only_note': 'Nota: este modo usa solo los subtítulos del propio video. Si el video no tiene subtítulos, no es posible generar texto sin transcripción offline.', 'translate_banner': 'El subtítulo parece estar en “{caption}”, diferente del idioma del sistema (“{system}”). ¿Deseas traducirlo?', 'dont_remind': 'No recordar', 'status_caption': 'Subtítulo: {lang}', 'no_favorite_channels': 'No hay canales en favoritos.', 'render_error': 'Error al renderizar la interfaz.', 'fatal_start_error': 'Fallo crítico al iniciar la aplicación.'
    },
    'ja': {
      'app_title': 'NewsTube', 'search': '検索', 'favorites': 'お気に入り', 'theme': 'テーマ', 'language': '言語', 'theme_light': 'ライト', 'theme_dark': 'ダーク', 'theme_system': 'システム', 'search_videos_channels': '動画とチャンネルを検索', 'type_search': '検索語を入力', 'reload': '再読み込み', 'copy': 'コピー', 'copied': 'テキストをコピーしました。', 'transcript': '文字起こし', 'loading': '読み込み中...', 'searching_captions': '字幕を検索しています...', 'failed': '失敗しました', 'translate': '翻訳', 'translation_done': '翻訳が完了しました', 'translation_failed': '現在テキストを翻訳できません。', 'translation_language': '翻訳言語', 'choose_once_auto': '一度選択すると、以後は自動翻訳されます', 'view_original': '原文を見る', 'view_translation': '翻訳を見る', 'grammar_fix': '文法を修正', 'grammar_fixed': '文法を修正しました。', 'grammar_failed': '現在文法を修正できません。', 'correcting_grammar': '文法を修正しています...', 'article': '記事', 'channel': 'チャンネル', 'channels': 'チャンネル', 'videos': '動画', 'favorite_channel': 'お気に入りチャンネル', 'remove_favorite': 'お気に入りから削除', 'read': '既読', 'no_favorites': 'まだお気に入りはありません。', 'search_channels': 'チャンネルを検索', 'enter_channel_name': 'チャンネル名を入力', 'no_channel_found': 'チャンネルが見つかりません。', 'no_video_found_channel': 'このチャンネルの動画は見つかりませんでした。', 'load_more_failed': 'これ以上動画を読み込めませんでした', 'error': 'エラー', 'captions_only_note': '注: このモードでは動画自身の字幕のみを使用します。動画に字幕がない場合、オフライン文字起こしなしではテキストを生成できません。', 'translate_banner': '字幕は「{caption}」で、システム言語（「{system}」）と異なるようです。翻訳しますか？', 'dont_remind': '今後表示しない', 'status_caption': '字幕: {lang}', 'no_favorite_channels': 'お気に入りのチャンネルがありません。', 'render_error': 'インターフェースの描画エラー。', 'fatal_start_error': 'アプリ起動時に重大なエラーが発生しました。'
    },
  };

  String t(String key, {Map<String, String> params = const {}}) {
    final lang = normalizeLanguageCode(languageCode);
    var value = _values[lang]?[key] ?? _values['en']?[key] ?? key;
    params.forEach((k, v) {
      value = value.replaceAll('{$k}', v);
    });
    return value;
  }
}
