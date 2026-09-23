import 'package:collega_app/features/colleges/domain/college_icons.dart';

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
  /// SVG de [CollegeIcons].
  final String icon;
}

const kCollegeCatalog = <CollegeCatalogEntry>[
  CollegeCatalogEntry(refId: 1,  name: 'Anatomie pathologique',                          editor: 'CoPath',    icon: CollegeIcons.microscope),
  CollegeCatalogEntry(refId: 2,  name: 'Anesthésie-Réanimation',                         editor: 'SFAR',      icon: CollegeIcons.medkit),
  CollegeCatalogEntry(refId: 3,  name: 'Cancérologie',                                   editor: 'CNEC',      icon: CollegeIcons.cancer),
  CollegeCatalogEntry(refId: 4,  name: 'Cardiologie',                                    editor: 'SFC',       icon: CollegeIcons.heart),
  CollegeCatalogEntry(refId: 5,  name: 'Chirurgie générale, viscérale et digestive',     editor: 'CFCVD',     icon: CollegeIcons.medkit),
  CollegeCatalogEntry(refId: 6,  name: 'Chirurgie maxillo-faciale et stomatologie',      editor: 'CMFCO',     icon: CollegeIcons.face),
  CollegeCatalogEntry(refId: 7,  name: 'Dermatologie',                                   editor: 'CEDEF',     icon: CollegeIcons.skin),
  CollegeCatalogEntry(refId: 8,  name: 'Douleur, soins palliatifs et accompagnement',    editor: 'CNEFUSP',   icon: CollegeIcons.hands),
  CollegeCatalogEntry(refId: 9,  name: 'Endocrinologie, diabétologie',                   editor: 'CEEDMM',    icon: CollegeIcons.flask),
  CollegeCatalogEntry(refId: 10, name: 'Gériatrie',                                      editor: 'CNEG',      icon: CollegeIcons.person),
  CollegeCatalogEntry(refId: 11, name: 'Gynécologie-Obstétrique',                        editor: 'CNGOF',     icon: CollegeIcons.female),
  CollegeCatalogEntry(refId: 12, name: 'Hématologie',                                    editor: 'SFH',       icon: CollegeIcons.drop),
  CollegeCatalogEntry(refId: 13, name: 'Hépato-Gastro-Entérologie',                      editor: 'CDU-HGE',   icon: CollegeIcons.flask),
  CollegeCatalogEntry(refId: 14, name: 'Imagerie médicale',                              editor: 'CERF',      icon: CollegeIcons.image),
  CollegeCatalogEntry(refId: 15, name: 'Immunopathologie',                               editor: 'ASSIM',     icon: CollegeIcons.shield),
  CollegeCatalogEntry(refId: 16, name: 'Infectiologie',                                  editor: 'CMIT',      icon: CollegeIcons.microbe),
  CollegeCatalogEntry(refId: 17, name: "Médecine d'urgence",                             editor: 'CNUMU',     icon: CollegeIcons.pulse),
  CollegeCatalogEntry(refId: 18, name: 'Médecine du travail',                            editor: 'CEHUMT',    icon: CollegeIcons.briefcase),
  CollegeCatalogEntry(refId: 19, name: 'Médecine et chirurgie vasculaire',               editor: 'CEMV',      icon: CollegeIcons.pulse),
  CollegeCatalogEntry(refId: 20, name: 'Médecine intensive – Réanimation',               editor: 'CeMIR',     icon: CollegeIcons.pulse),
  CollegeCatalogEntry(refId: 21, name: 'Médecine interne',                               editor: 'CEMI',      icon: CollegeIcons.stethoscope),
  CollegeCatalogEntry(refId: 22, name: 'Médecine légale',                                editor: 'CNEML',     icon: CollegeIcons.scale),
  CollegeCatalogEntry(refId: 23, name: 'Médecine physique et de réadaptation',           editor: 'COFEMER',   icon: CollegeIcons.person),
  CollegeCatalogEntry(refId: 24, name: 'Néphrologie',                                    editor: 'CUEN',      icon: CollegeIcons.kidney),
  CollegeCatalogEntry(refId: 25, name: 'Neurochirurgie',                                 editor: 'CN',        icon: CollegeIcons.brain),
  CollegeCatalogEntry(refId: 26, name: 'Neurologie',                                     editor: 'CEN',       icon: CollegeIcons.brain),
  CollegeCatalogEntry(refId: 27, name: 'Nutrition',                                      editor: 'CEN-Nut',   icon: CollegeIcons.apple),
  CollegeCatalogEntry(refId: 28, name: 'Ophtalmologie',                                  editor: 'COUF',      icon: CollegeIcons.eye),
  CollegeCatalogEntry(refId: 29, name: 'ORL et chirurgie cervico-faciale',               editor: 'CFORL',     icon: CollegeIcons.ear),
  CollegeCatalogEntry(refId: 30, name: 'Orthopédie-Traumatologie',                       editor: 'CFCOT',     icon: CollegeIcons.bone),
  CollegeCatalogEntry(refId: 31, name: 'Parasitoses et Mycoses',                         editor: 'ANOFEL',    icon: CollegeIcons.microbe),
  CollegeCatalogEntry(refId: 32, name: 'Pédiatrie',                                      editor: 'CNPU',      icon: CollegeIcons.child),
  CollegeCatalogEntry(refId: 33, name: 'Pharmacologie',                                  editor: 'CNPM',      icon: CollegeIcons.pill),
  CollegeCatalogEntry(refId: 34, name: 'Pneumologie',                                    editor: 'CEP',       icon: CollegeIcons.lungs),
  CollegeCatalogEntry(refId: 35, name: 'Psychiatrie',                                    editor: 'CNUP',      icon: CollegeIcons.mind),
  CollegeCatalogEntry(refId: 36, name: 'Rhumatologie',                                   editor: 'CoFER',     icon: CollegeIcons.bone),
  CollegeCatalogEntry(refId: 37, name: 'Santé publique',                                 editor: 'CUESP',     icon: CollegeIcons.globe),
  CollegeCatalogEntry(refId: 38, name: 'Sémiologie clinique',                            editor: 'CEMI',      icon: CollegeIcons.clipboard),
  CollegeCatalogEntry(refId: 39, name: 'Urologie',                                       editor: 'CFEU',      icon: CollegeIcons.kidney),
];

/// Entrée du catalogue pour [refId], ou `null` (ref inconnue, lien périmé).
CollegeCatalogEntry? collegeCatalogEntry(int refId) {
  for (final e in kCollegeCatalog) {
    if (e.refId == refId) return e;
  }
  return null;
}
