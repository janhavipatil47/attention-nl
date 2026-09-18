/// Developer-side research mapping registry for academic justification,
/// developer traceability, and supervisor review.
class ParameterResearchMapping {
  const ParameterResearchMapping({
    required this.parameter,
    required this.domain,
    required this.activity,
    required this.ageGroup,
    required this.level,
    required this.researchConstruct,
    required this.neurolearnMeasurement,
    required this.neurolearnFormula,
    required this.researchSource,
    required this.doiUrl,
    required this.evidenceType,
  });

  final String parameter;
  final String domain;
  final String activity;
  final String ageGroup;
  final String level;
  final String researchConstruct;
  final String neurolearnMeasurement;
  final String neurolearnFormula;
  final String researchSource;
  final String doiUrl;
  final String evidenceType;

  Map<String, String> toJson() => {
        'parameter': parameter,
        'domain': domain,
        'activity': activity,
        'age_group': ageGroup,
        'level': level,
        'research_construct': researchConstruct,
        'neurolearn_measurement': neurolearnMeasurement,
        'neurolearn_formula': neurolearnFormula,
        'research_source': researchSource,
        'doi_url': doiUrl,
        'evidence_type': evidenceType,
      };
}

class ResearchMappingService {
  static const List<ParameterResearchMapping> registry = [
    // --- Reading & Language ---
    ParameterResearchMapping(
      parameter: 'Rhyme Recognition',
      domain: 'Reading & Language',
      activity: 'Rhyme Match / Rhyme-Time Pop',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Phonological awareness and rhyming discrimination',
      neurolearnMeasurement: 'Auditory/visual rhyming response accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Singh et al. (2021) DALI-DAB, Annals of Dyslexia 71(2):299-317',
      doiUrl: 'https://doi.org/10.1007/s11881-021-00227-z',
      evidenceType: 'Direct task support',
    ),
    ParameterResearchMapping(
      parameter: 'Auditory Discrimination',
      domain: 'Reading & Language',
      activity: 'Sound Match / Audio Explorer',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Phonemic perception and auditory sound discrimination',
      neurolearnMeasurement: 'Phonemic audio matching accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Rauschenberger, Baeza-Yates & Rello (2022) Frontiers in Computer Science 3:628634',
      doiUrl: 'https://doi.org/10.3389/fcomp.2021.628634',
      evidenceType: 'Direct task support',
    ),
    ParameterResearchMapping(
      parameter: 'Letter-Sound Association',
      domain: 'Reading & Language',
      activity: 'Picture Pair / Image-to-Word Snap',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Phoneme-to-grapheme binding and cross-modal mapping',
      neurolearnMeasurement: 'Phoneme-grapheme matching accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Alkhurayyif & Sait (2024) Diagnostics 14(21):2362',
      doiUrl: 'https://doi.org/10.3390/diagnostics14212362',
      evidenceType: 'Construct support',
    ),
    ParameterResearchMapping(
      parameter: 'Word Recognition & Decoding',
      domain: 'Reading & Language',
      activity: 'Missing Letter / Reading Rainbow',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Grapheme sequencing and word decoding proficiency',
      neurolearnMeasurement: 'Word completion and decoding task accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Proença et al. (2017) Speech Communication 94:1-14',
      doiUrl: 'https://doi.org/10.1016/j.specom.2017.08.006',
      evidenceType: 'Construct support',
    ),

    // --- Handwriting & Writing ---
    ParameterResearchMapping(
      parameter: 'Controlled Tracing & Line Guidance',
      domain: 'Writing & Handwriting',
      activity: 'Tracing Practice / Arrow Tracing',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Fine motor line guidance and handwriting kinetics',
      neurolearnMeasurement: 'Touch-path deviation accuracy',
      neurolearnFormula: 'Controlled Tracing Path Accuracy = (on_path_touch_points / total_path_points) * 100',
      researchSource: 'Dankovičová, Hurtuk & Feciľak (2019) IEEE SISY pp. 149-154',
      doiUrl: 'https://doi.org/10.1109/SISY.2019.8931481',
      evidenceType: 'Measurement support',
    ),
    ParameterResearchMapping(
      parameter: 'Letter Formation & Shape Construction',
      domain: 'Writing & Handwriting',
      activity: 'Writing Wizard / Letter Builder',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Graphomotor stroke production and letter construction',
      neurolearnMeasurement: 'Stroke sequence completion accuracy',
      neurolearnFormula: 'Stroke Accuracy = (completed_valid_strokes / required_strokes) * 100',
      researchSource: 'Asselborn et al. (2018) npj Digital Medicine 1:42',
      doiUrl: 'https://doi.org/10.1038/s41746-018-0049-x',
      evidenceType: 'Measurement support',
    ),
    ParameterResearchMapping(
      parameter: 'Spatial Placement & Alignment',
      domain: 'Writing & Handwriting',
      activity: 'Busy Shapes / Letter Sorter',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Visual-spatial organization and spatial alignment',
      neurolearnMeasurement: 'Spatial placement and sorting accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Drotár & Dobeš (2020) Scientific Reports 10:21541',
      doiUrl: 'https://doi.org/10.1038/s41598-020-78611-9',
      evidenceType: 'Construct support',
    ),
    ParameterResearchMapping(
      parameter: 'Circular Motion & Motor Control',
      domain: 'Writing & Handwriting',
      activity: 'Circle Creation / Color Garden',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Curvilinear trajectory control and motor smoothness',
      neurolearnMeasurement: 'Curvilinear touch arc guidance completion',
      neurolearnFormula: 'Arc Completion = (arc_completed_degrees / 360) * 100',
      researchSource: 'Gargot et al. (2020) PLOS ONE 15(9):e0237575',
      doiUrl: 'https://doi.org/10.1371/journal.pone.0237575',
      evidenceType: 'Measurement support',
    ),

    // --- Mathematics & Numeracy ---
    ParameterResearchMapping(
      parameter: 'Counting & One-to-One Correspondence',
      domain: 'Mathematics & Numeracy',
      activity: 'Count Objects / Animal Counting Corral',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'One-to-one enumeration and early quantity representation',
      neurolearnMeasurement: 'Object enumeration accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Räsänen et al. (2009) Cognitive Development 24(4):450-472',
      doiUrl: 'https://doi.org/10.1016/j.cogdev.2009.09.003',
      evidenceType: 'Direct task support',
    ),
    ParameterResearchMapping(
      parameter: 'Subitizing & Numerosity Recognition',
      domain: 'Mathematics & Numeracy',
      activity: 'Find Dots / Visual-to-Symbol Table',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Non-symbolic subitizing and symbolic magnitude mapping',
      neurolearnMeasurement: 'Dot quantity recognition accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Wilson et al. (2006) Behavioral and Brain Functions 2:19',
      doiUrl: 'https://doi.org/10.1186/1744-9081-2-19',
      evidenceType: 'Direct task support',
    ),
    ParameterResearchMapping(
      parameter: 'Size & Quantity Comparison',
      domain: 'Mathematics & Numeracy',
      activity: 'Size Comparison / Dice Path Sequencing',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Mental number line representation and ordinal magnitude comparison',
      neurolearnMeasurement: 'Magnitude comparison accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Kucian et al. (2011) NeuroImage 57(3):782-795',
      doiUrl: 'https://doi.org/10.1016/j.neuroimage.2011.01.070',
      evidenceType: 'Direct task support',
    ),
    ParameterResearchMapping(
      parameter: 'Sequential Number Memory & Ordering',
      domain: 'Mathematics & Numeracy',
      activity: 'Number Sequence',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Numerical working memory and ordinal sequence retention',
      neurolearnMeasurement: 'Number sequence recall accuracy',
      neurolearnFormula: 'Accuracy = (correct_valid_responses / total_valid_responses) * 100',
      researchSource: 'Aunio & Mononen (2018) European Journal of Special Needs Education 33(5):677-691',
      doiUrl: 'https://doi.org/10.1080/08856257.2017.1412640',
      evidenceType: 'Direct task support',
    ),

    // --- Attention & Cognitive Control ---
    ParameterResearchMapping(
      parameter: 'Sustained Visual Attention',
      domain: 'Attention & Cognitive Control',
      activity: 'Dino Feeding / Geometric Shape Detective',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Vigilance, target discrimination, and distractor suppression',
      neurolearnMeasurement: 'Target discrimination hit rate',
      neurolearnFormula: 'Hit Rate = (target_hits / total_targets) * 100',
      researchSource: 'Huang-Pollock et al. (2012) Journal of Abnormal Psychology 121(2):360-371',
      doiUrl: 'https://doi.org/10.1037/a0027205',
      evidenceType: 'Construct support',
    ),
    ParameterResearchMapping(
      parameter: 'Reaction Time Variability (SDRT)',
      domain: 'Attention & Cognitive Control',
      activity: 'Task Response Timing',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Intra-individual response time variability and attention stability',
      neurolearnMeasurement: 'Sample standard deviation of response times across trials (ms)',
      neurolearnFormula: 'SDRT = sqrt( sum( (RT_i - meanRT)^2 ) / (N - 1) ) for N >= 3 valid reaction-time observations',
      researchSource: 'Kofler et al. (2013) Clinical Psychology Review 33(6):795-811',
      doiUrl: 'https://doi.org/10.1016/j.cpr.2013.06.001',
      evidenceType: 'Measurement support',
    ),
    ParameterResearchMapping(
      parameter: 'Visual Gaze Orientation (Webcam Proxy)',
      domain: 'Attention & Cognitive Control',
      activity: 'OpenCV Live Camera Gaze Tracker',
      ageGroup: '3–5 & 6–7',
      level: 'Level 1, 2, 3',
      researchConstruct: 'Gaze dispersion and visual attention stability (Webcam proxy; not high-frequency eye tracker)',
      neurolearnMeasurement: 'In-bounds gaze time percentage',
      neurolearnFormula: 'In-Bounds Gaze Percentage = (attentive_seconds / total_tracked_seconds) * 100',
      researchSource: 'Vision Journal Study (2025) Vision 9(3):76',
      doiUrl: 'https://doi.org/10.3390/vision9030076',
      evidenceType: 'Related developmental evidence',
    ),
  ];

  static List<ParameterResearchMapping> getMappingsForDomain(String domain) {
    return registry.where((m) => m.domain.toLowerCase() == domain.toLowerCase()).toList();
  }
}
