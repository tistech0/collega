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
  CollegeCatalogEntry(refId: 1,  name: 'Anatomie pathologique',                          editor: 'CoPath',    icon: Icons.zoom_in_outlined),
  CollegeCatalogEntry(refId: 2,  name: 'Anesthésie-Réanimation',                         editor: 'SFAR',      icon: Icons.medical_services_outlined),
  CollegeCatalogEntry(refId: 3,  name: 'Cancérologie',                                   editor: 'CNEC',      icon: Icons.vaccines_outlined),
  CollegeCatalogEntry(refId: 4,  name: 'Cardiologie',                                    editor: 'SFC',       icon: Icons.favorite_border),
  CollegeCatalogEntry(refId: 5,  name: 'Chirurgie générale, viscérale et digestive',     editor: 'CFCVD',     icon: Icons.medical_services_outlined),
  CollegeCatalogEntry(refId: 6,  name: 'Chirurgie maxillo-faciale et stomatologie',      editor: 'CMFCO',     icon: Icons.face_outlined),
  CollegeCatalogEntry(refId: 7,  name: 'Dermatologie',                                   editor: 'CEDEF',     icon: Icons.spa_outlined),
  CollegeCatalogEntry(refId: 8,  name: 'Douleur, soins palliatifs et accompagnement',    editor: 'CNEFUSP',   icon: Icons.volunteer_activism_outlined),
  CollegeCatalogEntry(refId: 9,  name: 'Endocrinologie, diabétologie',                   editor: 'CEEDMM',    icon: Icons.science_outlined),
  CollegeCatalogEntry(refId: 10, name: 'Gériatrie',                                      editor: 'CNEG',      icon: Icons.elderly_outlined),
  CollegeCatalogEntry(refId: 11, name: 'Gynécologie-Obstétrique',                        editor: 'CNGOF',     icon: Icons.pregnant_woman_outlined),
  CollegeCatalogEntry(refId: 12, name: 'Hématologie',                                    editor: 'SFH',       icon: Icons.water_drop_outlined),
  CollegeCatalogEntry(refId: 13, name: 'Hépato-Gastro-Entérologie',                      editor: 'CDU-HGE',   icon: Icons.biotech_outlined),
  CollegeCatalogEntry(refId: 14, name: 'Imagerie médicale',                              editor: 'CERF',      icon: Icons.document_scanner_outlined),
  CollegeCatalogEntry(refId: 15, name: 'Immunopathologie',                               editor: 'ASSIM',     icon: Icons.shield_outlined),
  CollegeCatalogEntry(refId: 16, name: 'Infectiologie',                                  editor: 'CMIT',      icon: Icons.bug_report_outlined),
  CollegeCatalogEntry(refId: 17, name: "Médecine d'urgence",                             editor: 'CNUMU',     icon: Icons.local_hospital_outlined),
  CollegeCatalogEntry(refId: 18, name: 'Médecine du travail',                            editor: 'CEHUMT',    icon: Icons.work_outline),
  CollegeCatalogEntry(refId: 19, name: 'Médecine et chirurgie vasculaire',               editor: 'CEMV',      icon: Icons.bloodtype_outlined),
  CollegeCatalogEntry(refId: 20, name: 'Médecine intensive – Réanimation',               editor: 'CeMIR',     icon: Icons.monitor_heart_outlined),
  CollegeCatalogEntry(refId: 21, name: 'Médecine interne',                               editor: 'CEMI',      icon: Icons.medical_information_outlined),
  CollegeCatalogEntry(refId: 22, name: 'Médecine légale',                                editor: 'CNEML',     icon: Icons.gavel),
  CollegeCatalogEntry(refId: 23, name: 'Médecine physique et de réadaptation',           editor: 'COFEMER',   icon: Icons.accessibility_outlined),
  CollegeCatalogEntry(refId: 24, name: 'Néphrologie',                                    editor: 'CUEN',      icon: Icons.filter_alt_outlined),
  CollegeCatalogEntry(refId: 25, name: 'Neurochirurgie',                                 editor: 'CN',        icon: Icons.psychology_alt_outlined),
  CollegeCatalogEntry(refId: 26, name: 'Neurologie',                                     editor: 'CEN',       icon: Icons.psychology_outlined),
  CollegeCatalogEntry(refId: 27, name: 'Nutrition',                                      editor: 'CEN-Nut',   icon: Icons.restaurant_outlined),
  CollegeCatalogEntry(refId: 28, name: 'Ophtalmologie',                                  editor: 'COUF',      icon: Icons.visibility_outlined),
  CollegeCatalogEntry(refId: 29, name: 'ORL et chirurgie cervico-faciale',               editor: 'CFORL',     icon: Icons.hearing_outlined),
  CollegeCatalogEntry(refId: 30, name: 'Orthopédie-Traumatologie',                       editor: 'CFCOT',     icon: Icons.healing_outlined),
  CollegeCatalogEntry(refId: 31, name: 'Parasitoses et Mycoses',                         editor: 'ANOFEL',    icon: Icons.coronavirus_outlined),
  CollegeCatalogEntry(refId: 32, name: 'Pédiatrie',                                      editor: 'CNPU',      icon: Icons.child_care_outlined),
  CollegeCatalogEntry(refId: 33, name: 'Pharmacologie',                                  editor: 'CNPM',      icon: Icons.medication_outlined),
  CollegeCatalogEntry(refId: 34, name: 'Pneumologie',                                    editor: 'CEP',       icon: Icons.air_outlined),
  CollegeCatalogEntry(refId: 35, name: 'Psychiatrie',                                    editor: 'CNUP',      icon: Icons.self_improvement_outlined),
  CollegeCatalogEntry(refId: 36, name: 'Rhumatologie',                                   editor: 'CoFER',     icon: Icons.accessibility_new_outlined),
  CollegeCatalogEntry(refId: 37, name: 'Santé publique',                                 editor: 'CUESP',     icon: Icons.public_outlined),
  CollegeCatalogEntry(refId: 38, name: 'Sémiologie clinique',                            editor: 'CEMI',      icon: Icons.assignment_outlined),
  CollegeCatalogEntry(refId: 39, name: 'Urologie',                                       editor: 'CFEU',      icon: Icons.water_outlined),
];
