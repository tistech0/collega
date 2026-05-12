import 'package:flutter/material.dart';

class CollegeCatalogEntry {
  const CollegeCatalogEntry({
    required this.refId,
    required this.name,
    required this.editor,
    required this.icon,
  });
  final int refId;
  final String name;
  final String editor;
  final IconData icon;
}

const kCollegeCatalog = <CollegeCatalogEntry>[
  CollegeCatalogEntry(refId: 1,  name: 'Cardiologie et maladies vasculaires',     editor: 'CNEC',    icon: Icons.favorite_border),
  CollegeCatalogEntry(refId: 2,  name: 'Dermatologie',                            editor: 'CEDEF',   icon: Icons.spa_outlined),
  CollegeCatalogEntry(refId: 3,  name: 'Endocrinologie, diabétologie, nutrition', editor: 'CEEDMM',  icon: Icons.science_outlined),
  CollegeCatalogEntry(refId: 4,  name: 'Gastroentérologie et hépatologie',        editor: 'CDU-HGE', icon: Icons.biotech_outlined),
  CollegeCatalogEntry(refId: 5,  name: 'Gériatrie',                               editor: 'CNPG',    icon: Icons.elderly_outlined),
  CollegeCatalogEntry(refId: 6,  name: 'Hématologie',                             editor: 'CEM',     icon: Icons.water_drop_outlined),
  CollegeCatalogEntry(refId: 7,  name: 'Infectiologie',                           editor: 'SPILF',   icon: Icons.bug_report_outlined),
  CollegeCatalogEntry(refId: 8,  name: 'Médecine interne et maladies rares',      editor: 'CRI',     icon: Icons.medical_services_outlined),
  CollegeCatalogEntry(refId: 9,  name: "Médecine d'urgence",                      editor: 'SFMU',    icon: Icons.local_hospital_outlined),
  CollegeCatalogEntry(refId: 10, name: 'Médecine générale',                       editor: 'CMGE',    icon: Icons.home_outlined),
  CollegeCatalogEntry(refId: 11, name: 'Médecine légale',                         editor: 'CNMLF',   icon: Icons.gavel),
  CollegeCatalogEntry(refId: 12, name: 'Médecine physique et réadaptation',       editor: 'COFEMER', icon: Icons.accessibility_outlined),
  CollegeCatalogEntry(refId: 13, name: 'Médecine vasculaire',                     editor: 'SFmv',    icon: Icons.bloodtype_outlined),
  CollegeCatalogEntry(refId: 14, name: 'Néphrologie',                             editor: 'CNP',     icon: Icons.filter_alt_outlined),
  CollegeCatalogEntry(refId: 15, name: 'Neurologie',                              editor: 'CEN',     icon: Icons.psychology_outlined),
  CollegeCatalogEntry(refId: 16, name: 'Oncologie médicale',                      editor: 'SNFGE',   icon: Icons.vaccines_outlined),
  CollegeCatalogEntry(refId: 17, name: 'Ophtalmologie',                           editor: 'COUF',    icon: Icons.visibility_outlined),
  CollegeCatalogEntry(refId: 18, name: 'ORL et chirurgie cervico-faciale',        editor: 'SFORL',   icon: Icons.hearing_outlined),
  CollegeCatalogEntry(refId: 19, name: 'Orthopédie-Traumatologie',                editor: 'SOFCOT',  icon: Icons.healing_outlined),
  CollegeCatalogEntry(refId: 20, name: 'Pédiatrie',                               editor: 'CNPU',    icon: Icons.child_care_outlined),
  CollegeCatalogEntry(refId: 21, name: 'Pneumologie et addictologie',             editor: 'CEP',     icon: Icons.air_outlined),
  CollegeCatalogEntry(refId: 22, name: 'Psychiatrie',                             editor: 'AEPU',    icon: Icons.self_improvement_outlined),
  CollegeCatalogEntry(refId: 23, name: 'Radiologie et imagerie médicale',         editor: 'CERF',    icon: Icons.document_scanner_outlined),
  CollegeCatalogEntry(refId: 24, name: 'Réanimation médicale',                    editor: 'SRLF',    icon: Icons.monitor_heart_outlined),
  CollegeCatalogEntry(refId: 25, name: 'Rhumatologie',                            editor: 'CRF',     icon: Icons.accessibility_new_outlined),
  CollegeCatalogEntry(refId: 26, name: 'Urologie',                                editor: 'AFU',     icon: Icons.water_outlined),
  CollegeCatalogEntry(refId: 27, name: 'Chirurgie digestive et viscérale',        editor: 'ACHBT',   icon: Icons.medical_services_outlined),
  CollegeCatalogEntry(refId: 28, name: 'Chirurgie cardiaque et thoracique',       editor: 'SFCTCV',  icon: Icons.favorite_outlined),
  CollegeCatalogEntry(refId: 29, name: 'Chirurgie plastique et reconstructrice',  editor: 'SOFCPRE', icon: Icons.brush_outlined),
  CollegeCatalogEntry(refId: 30, name: 'Neurochirurgie',                          editor: 'SNCLF',   icon: Icons.psychology_outlined),
  CollegeCatalogEntry(refId: 31, name: 'Gynécologie-Obstétrique',                 editor: 'CNGOF',   icon: Icons.pregnant_woman_outlined),
  CollegeCatalogEntry(refId: 32, name: 'Anesthésiologie-réanimation',             editor: 'SFAR',    icon: Icons.medical_services_outlined),
  CollegeCatalogEntry(refId: 33, name: 'Anatomie et cytologie pathologiques',     editor: 'CNECAP',  icon: Icons.zoom_in_outlined),
  CollegeCatalogEntry(refId: 34, name: 'Biochimie médicale',                      editor: 'SFBC',    icon: Icons.science_outlined),
  CollegeCatalogEntry(refId: 35, name: 'Génétique médicale',                      editor: 'CNMG',    icon: Icons.biotech_outlined),
  CollegeCatalogEntry(refId: 36, name: 'Immunologie médicale',                    editor: 'SNFMI',   icon: Icons.shield_outlined),
  CollegeCatalogEntry(refId: 37, name: 'Médecine du travail',                     editor: 'SF2MT',   icon: Icons.work_outline),
  CollegeCatalogEntry(refId: 38, name: 'Microbiologie médicale',                  editor: 'CMIT',    icon: Icons.coronavirus_outlined),
  CollegeCatalogEntry(refId: 39, name: 'Pharmacologie médicale',                  editor: 'CNPM',    icon: Icons.medication_outlined),
  CollegeCatalogEntry(refId: 40, name: 'Santé publique et économie de la santé',  editor: 'APES',    icon: Icons.public_outlined),
];
