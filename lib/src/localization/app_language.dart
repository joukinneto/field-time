import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  en('English', 'en'),
  pt('Portugues', 'pt'),
  es('Espanol', 'es');

  const AppLanguage(this.label, this.code);

  final String label;
  final String code;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (language) => language.code == code,
        orElse: () => AppLanguage.en,
      );
}

final appLanguageControllerProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>(
  (ref) => AppLanguageController()..load(),
);

final class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguage.en);

  static const _key = 'field_time_language';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppLanguage.fromCode(prefs.getString(_key));
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.code);
  }
}

final class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String t(String key) {
    final selected = _strings[language]?[key];
    if (selected != null && selected.trim().isNotEmpty) return selected;
    final fallback = _strings[AppLanguage.en]?[key];
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return _fallbackHumanText(key);
  }
}

extension AppStringsContext on BuildContext {
  String tr(String key) {
    final container = ProviderScope.containerOf(this, listen: true);
    return AppStrings(container.read(appLanguageControllerProvider)).t(key);
  }
}

String _fallbackHumanText(String key) {
  final words = key
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
    return '${match.group(1)} ${match.group(2)}';
  }).trim();
  if (words.isEmpty) return 'Field Time';
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

const _strings = {
  AppLanguage.en: {
    'app.title': 'Field Time',
    'nav.home': 'Home',
    'nav.timesheet': 'Timesheet',
    'nav.jobs': 'Jobs',
    'nav.receipts': 'Receipts',
    'nav.management': 'Management',
    'nav.menu': 'Menu',
    'settings.title': 'Settings',
    'settings.subtitle': 'Profile, pilot controls and app preferences.',
    'settings.preferences': 'Preferences',
    'settings.language': 'Language',
    'settings.languageHelp': 'Choose the app language.',
    'settings.saved': 'Language saved.',
    'timesheet.title': 'Timesheet',
    'timesheet.subtitle': 'Review hours, jobs, receipts and export readiness.',
    'timesheet.generatePdf': 'Generate PDF',
    'timesheet.previewPdf': 'Preview PDF',
    'timesheet.period': 'Period',
    'timesheet.today': 'Today',
    'timesheet.week': 'Week',
    'timesheet.month': 'Month',
    'timesheet.year': 'Year',
    'timesheet.dailyRecords': 'Daily records',
    'timesheet.noRecords': 'No records for this period',
    'timesheet.noRecordsHelp': 'Clocked work periods will appear here.',
    'approval.approve': 'Approve',
    'approval.reject': 'Reject',
    'approval.review': 'Review',
    'approval.pending': 'Pending',
    'approval.approved': 'Approved',
    'approval.rejected': 'Rejected',
    'approval.underReview': 'Under review',
    'approval.corrected': 'Corrected',
    'approval.resubmitted': 'Resubmitted',
    'approval.reason': 'Reason',
    'approval.observation': 'Observation',
    'approval.confirmApprove': 'Approve this time record?',
    'approval.confirmReject': 'Reject this time record?',
    'approval.history': 'Review history',
    'jobs.title': 'Jobs',
    'jobs.subtitle': 'Visual directory of available Field Time jobs.',
    'status.active': 'Active',
    'status.inactive': 'Inactive',
  },
  AppLanguage.pt: {
    'app.title': 'Field Time',
    'nav.home': 'Inicio',
    'nav.timesheet': 'Folha',
    'nav.jobs': 'Obras',
    'nav.receipts': 'Recibos',
    'nav.management': 'Gestao',
    'nav.menu': 'Menu',
    'settings.title': 'Configuracoes',
    'settings.subtitle': 'Perfil, controles do piloto e preferencias.',
    'settings.preferences': 'Preferencias',
    'settings.language': 'Idioma',
    'settings.languageHelp': 'Escolha o idioma do aplicativo.',
    'settings.saved': 'Idioma salvo.',
    'timesheet.title': 'Timesheet',
    'timesheet.subtitle': 'Revise horas, obras, recibos e exportacao.',
    'timesheet.generatePdf': 'Gerar PDF',
    'timesheet.previewPdf': 'Visualizar PDF',
    'timesheet.period': 'Periodo',
    'timesheet.today': 'Hoje',
    'timesheet.week': 'Semana',
    'timesheet.month': 'Mes',
    'timesheet.year': 'Ano',
    'timesheet.dailyRecords': 'Registros diarios',
    'timesheet.noRecords': 'Sem registros neste periodo',
    'timesheet.noRecordsHelp': 'Periodos trabalhados aparecerao aqui.',
    'approval.approve': 'Aprovar',
    'approval.reject': 'Rejeitar',
    'approval.review': 'Revisar',
    'approval.pending': 'Pendente',
    'approval.approved': 'Aprovado',
    'approval.rejected': 'Rejeitado',
    'approval.underReview': 'Em revisao',
    'approval.corrected': 'Corrigido',
    'approval.resubmitted': 'Reenviado',
    'approval.reason': 'Motivo',
    'approval.observation': 'Observacao',
    'approval.confirmApprove': 'Aprovar este registro de horas?',
    'approval.confirmReject': 'Rejeitar este registro de horas?',
    'approval.history': 'Historico de revisao',
    'jobs.title': 'Obras',
    'jobs.subtitle': 'Diretorio visual das obras disponiveis.',
    'status.active': 'Ativa',
    'status.inactive': 'Inativa',
  },
  AppLanguage.es: {
    'app.title': 'Field Time',
    'nav.home': 'Inicio',
    'nav.timesheet': 'Horas',
    'nav.jobs': 'Obras',
    'nav.receipts': 'Recibos',
    'nav.management': 'Gestion',
    'nav.menu': 'Menu',
    'settings.title': 'Configuracion',
    'settings.subtitle': 'Perfil, controles piloto y preferencias.',
    'settings.preferences': 'Preferencias',
    'settings.language': 'Idioma',
    'settings.languageHelp': 'Elija el idioma de la aplicacion.',
    'settings.saved': 'Idioma guardado.',
    'timesheet.title': 'Timesheet',
    'timesheet.subtitle': 'Revise horas, obras, recibos y exportacion.',
    'timesheet.generatePdf': 'Generar PDF',
    'timesheet.previewPdf': 'Vista previa PDF',
    'timesheet.period': 'Periodo',
    'timesheet.today': 'Hoy',
    'timesheet.week': 'Semana',
    'timesheet.month': 'Mes',
    'timesheet.year': 'Ano',
    'timesheet.dailyRecords': 'Registros diarios',
    'timesheet.noRecords': 'Sin registros en este periodo',
    'timesheet.noRecordsHelp': 'Los periodos trabajados apareceran aqui.',
    'approval.approve': 'Aprobar',
    'approval.reject': 'Rechazar',
    'approval.review': 'Revisar',
    'approval.pending': 'Pendiente',
    'approval.approved': 'Aprobado',
    'approval.rejected': 'Rechazado',
    'approval.underReview': 'En revision',
    'approval.corrected': 'Corregido',
    'approval.resubmitted': 'Reenviado',
    'approval.reason': 'Motivo',
    'approval.observation': 'Observacion',
    'approval.confirmApprove': 'Aprobar este registro de horas?',
    'approval.confirmReject': 'Rechazar este registro de horas?',
    'approval.history': 'Historial de revision',
    'jobs.title': 'Obras',
    'jobs.subtitle': 'Directorio visual de obras disponibles.',
    'status.active': 'Activa',
    'status.inactive': 'Inactiva',
  },
};
