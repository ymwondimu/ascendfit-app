import Foundation

enum ExerciseCategory: String, CaseIterable, Sendable {
    case legs = "Legs"
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
}

enum CatalogExerciseModality: Sendable {
    case weighted
    case bodyweight
    case assisted
    case timed(defaultSeconds: Int)
}

struct CatalogExercise: Identifiable, Sendable {
    let id: Int
    let name: String
    let aliases: [String]
    let category: ExerciseCategory
    let equipment: String
    let muscles: [String]
    let description: String
    let defaultSets: Int
    let defaultReps: Int
    let defaultRestSeconds: Int
    let modality: CatalogExerciseModality

    var definition: ExerciseDefinition {
        try! ExerciseDefinition(
            id: stableUUID,
            name: name,
            aliases: Set(aliases),
            description: description,
            equipment: equipment,
            primaryMuscles: muscles
        )
    }

    var searchableText: String {
        ([name, category.rawValue, equipment] + aliases + muscles)
            .joined(separator: " ")
    }

    var executionCue: String {
        switch id {
        case 1: "Brace your trunk. Keep your whole foot planted and knees tracking with your toes. Stand up with control."
        case 2: "Keep your elbows lifted and trunk braced. Let your knees track with your toes as you squat."
        case 3: "Hold the weight close to your chest. Keep your whole foot planted and lower with control."
        case 5: "Keep a soft bend in your knees. Push your hips back and keep the weight close to your legs."
        case 6: "Brace before you pull. Keep the bar close and push through the floor to stand tall."
        case 16, 17, 18, 19: "Plant your feet and keep your upper back supported. Lower with control, then press without bouncing."
        case 22: "Brace your trunk and keep your body in one line. Lower your chest with control, then press the floor away."
        case 24, 25: "Start from a controlled hang. Pull without swinging and lower yourself smoothly."
        case 26: "Keep your torso steady. Pull your elbows down toward your sides and return the handle with control."
        case 27, 28, 29, 30, 31: "Keep your trunk steady. Draw your elbows back without jerking the weight, then lower with control."
        case 35, 36: "Brace your trunk and keep your ribs controlled. Press overhead without leaning back."
        case 41, 42, 43, 44, 45: "Keep your upper arms steady. Curl without swinging and lower the weight with control."
        case 49, 50: "Brace your trunk and keep your hips aligned with your shoulders. Breathe steadily throughout the hold."
        default: description
        }
    }

    private var stableUUID: UUID {
        let value = String(format: "00000000-0000-0000-0000-%012d", id)
        return UUID(uuidString: value)!
    }
}

enum ExerciseCatalog {
    static let exercises: [CatalogExercise] = [
        e(1, "Back Squat", ["Barbell Squat"], .legs, "Barbell", ["Quadriceps", "Glutes"], "A barbell squat performed with the bar supported across the upper back.", 3, 5, 150),
        e(2, "Front Squat", [], .legs, "Barbell", ["Quadriceps", "Core"], "A squat with the bar held across the front of the shoulders.", 3, 5, 150),
        e(3, "Goblet Squat", [], .legs, "Dumbbell or kettlebell", ["Quadriceps", "Glutes"], "A squat holding one weight close to the chest.", 3, 10, 90),
        e(4, "Leg Press", [], .legs, "Leg press machine", ["Quadriceps", "Glutes"], "A machine press that extends the hips and knees against a platform.", 3, 10, 120),
        e(5, "Romanian Deadlift", ["RDL"], .legs, "Barbell or dumbbells", ["Hamstrings", "Glutes"], "A hip hinge emphasizing the hamstrings with a controlled lower.", 3, 8, 120),
        e(6, "Conventional Deadlift", ["Deadlift"], .legs, "Barbell", ["Glutes", "Hamstrings", "Back"], "A floor pull that extends the hips and knees to standing.", 3, 5, 180),
        e(7, "Sumo Deadlift", [], .legs, "Barbell", ["Glutes", "Adductors"], "A deadlift performed with a wide stance and hands inside the legs.", 3, 5, 180),
        e(8, "Hip Thrust", [], .legs, "Barbell or machine", ["Glutes"], "A loaded hip extension performed with the upper back supported.", 3, 10, 120),
        e(9, "Bulgarian Split Squat", ["Rear-Foot-Elevated Split Squat"], .legs, "Dumbbells", ["Quadriceps", "Glutes"], "A split squat with the rear foot elevated on a bench.", 3, 8, 90),
        e(10, "Walking Lunge", [], .legs, "Bodyweight or dumbbells", ["Quadriceps", "Glutes"], "Alternating forward lunges performed while traveling.", 3, 10, 90),
        e(11, "Reverse Lunge", [], .legs, "Bodyweight or dumbbells", ["Quadriceps", "Glutes"], "A lunge initiated by stepping backward.", 3, 8, 90),
        e(12, "Leg Extension", [], .legs, "Leg extension machine", ["Quadriceps"], "A seated machine exercise that extends the knees.", 3, 12, 75),
        e(13, "Seated Leg Curl", [], .legs, "Leg curl machine", ["Hamstrings"], "A seated machine exercise that bends the knees against resistance.", 3, 12, 75),
        e(14, "Lying Leg Curl", [], .legs, "Leg curl machine", ["Hamstrings"], "A prone machine exercise that bends the knees against resistance.", 3, 12, 75),
        e(15, "Standing Calf Raise", [], .legs, "Machine or dumbbells", ["Calves"], "A straight-leg calf raise performed from a standing position.", 3, 12, 60),
        e(16, "Barbell Bench Press", ["Bench Press"], .chest, "Barbell", ["Chest", "Triceps"], "A horizontal press performed lying on a flat bench.", 3, 8, 120),
        e(17, "Dumbbell Bench Press", [], .chest, "Dumbbells", ["Chest", "Triceps"], "A flat-bench press performed with independent dumbbells.", 3, 10, 90),
        e(18, "Incline Barbell Bench Press", ["Incline Bench Press"], .chest, "Barbell", ["Upper Chest", "Triceps"], "A barbell press performed on an inclined bench.", 3, 8, 120),
        e(19, "Incline Dumbbell Press", ["Incline Dumbbell Bench Press"], .chest, "Dumbbells", ["Upper Chest", "Triceps"], "An incline press performed with independent dumbbells.", 3, 10, 90),
        e(20, "Machine Chest Press", [], .chest, "Chest press machine", ["Chest", "Triceps"], "A guided horizontal pressing movement.", 3, 10, 90),
        e(21, "Cable Fly", ["Cable Crossover"], .chest, "Cable machine", ["Chest"], "A cable adduction movement that brings the arms together.", 3, 12, 60),
        e(22, "Push-Up", ["Pushup"], .chest, "Bodyweight", ["Chest", "Triceps"], "A bodyweight press from a plank position.", 3, 10, 60, .bodyweight),
        e(23, "Dip", ["Chest Dip"], .chest, "Dip bars", ["Chest", "Triceps"], "A bodyweight press performed between parallel bars.", 3, 8, 90, .bodyweight),
        e(24, "Pull-Up", ["Pullup"], .back, "Pull-up bar", ["Lats", "Upper Back"], "A vertical bodyweight pull bringing the chest toward a bar.", 3, 6, 120, .bodyweight),
        e(25, "Chin-Up", ["Chinup"], .back, "Pull-up bar", ["Lats", "Biceps"], "A supinated-grip vertical bodyweight pull.", 3, 6, 120, .bodyweight),
        e(26, "Lat Pulldown", [], .back, "Cable machine", ["Lats", "Upper Back"], "A seated vertical pull bringing a cable bar toward the upper chest.", 3, 10, 90),
        e(27, "Barbell Row", ["Bent-Over Row"], .back, "Barbell", ["Upper Back", "Lats"], "A hinged horizontal pull with a barbell.", 3, 8, 120),
        e(28, "One-Arm Dumbbell Row", ["Dumbbell Row"], .back, "Dumbbell", ["Lats", "Upper Back"], "A supported unilateral horizontal pull.", 3, 10, 90),
        e(29, "Seated Cable Row", [], .back, "Cable machine", ["Upper Back", "Lats"], "A seated horizontal cable pull toward the torso.", 3, 10, 90),
        e(30, "Chest-Supported Row", ["Chest-Supported Machine Row"], .back, "Machine or dumbbells", ["Upper Back", "Lats"], "A row performed with the chest supported to limit torso movement.", 3, 10, 90),
        e(31, "T-Bar Row", [], .back, "T-bar row machine", ["Upper Back", "Lats"], "A landmine or machine row using a neutral pulling path.", 3, 8, 120),
        e(32, "Straight-Arm Pulldown", [], .back, "Cable machine", ["Lats"], "A shoulder-extension cable movement performed with mostly straight arms.", 3, 12, 60),
        e(33, "Face Pull", [], .back, "Cable machine", ["Rear Delts", "Upper Back"], "A rope pull toward the face with external shoulder rotation.", 3, 15, 60),
        e(34, "Inverted Row", ["Body Row"], .back, "Bar or suspension trainer", ["Upper Back", "Lats"], "A bodyweight horizontal pull with the feet supported on the floor.", 3, 10, 75, .bodyweight),
        e(35, "Overhead Press", ["Military Press"], .shoulders, "Barbell", ["Shoulders", "Triceps"], "A standing vertical press with a barbell.", 3, 8, 120),
        e(36, "Seated Dumbbell Shoulder Press", ["Dumbbell Shoulder Press"], .shoulders, "Dumbbells", ["Shoulders", "Triceps"], "A seated vertical press with independent dumbbells.", 3, 10, 90),
        e(37, "Arnold Press", [], .shoulders, "Dumbbells", ["Shoulders"], "A rotating dumbbell shoulder press.", 3, 10, 90),
        e(38, "Dumbbell Lateral Raise", ["Lateral Raise"], .shoulders, "Dumbbells", ["Side Delts"], "A shoulder abduction movement raising dumbbells out to the sides.", 3, 12, 60),
        e(39, "Cable Lateral Raise", [], .shoulders, "Cable machine", ["Side Delts"], "A single-arm lateral raise using cable resistance.", 3, 12, 60),
        e(40, "Reverse Pec Deck", ["Rear Delt Fly"], .shoulders, "Pec deck machine", ["Rear Delts", "Upper Back"], "A supported reverse fly emphasizing the rear shoulders.", 3, 12, 60),
        e(41, "Barbell Curl", [], .arms, "Barbell", ["Biceps"], "A standing elbow curl performed with a barbell.", 3, 10, 75),
        e(42, "Dumbbell Curl", [], .arms, "Dumbbells", ["Biceps"], "An elbow curl performed with independent dumbbells.", 3, 10, 60),
        e(43, "Hammer Curl", [], .arms, "Dumbbells", ["Biceps", "Brachialis"], "A dumbbell curl performed with a neutral grip.", 3, 10, 60),
        e(44, "Preacher Curl", [], .arms, "Preacher bench", ["Biceps"], "A curl performed with the upper arms supported on a pad.", 3, 10, 75),
        e(45, "Cable Curl", [], .arms, "Cable machine", ["Biceps"], "An elbow curl using continuous cable resistance.", 3, 12, 60),
        e(46, "Triceps Pushdown", ["Cable Pushdown", "Cable Rope Triceps Pushdown"], .arms, "Cable machine", ["Triceps"], "A cable elbow-extension movement performed with the arms by the torso.", 3, 12, 60),
        e(47, "Overhead Triceps Extension", [], .arms, "Cable or dumbbell", ["Triceps"], "An elbow extension performed with the upper arms overhead.", 3, 12, 60),
        e(48, "Skull Crusher", ["Lying Triceps Extension"], .arms, "EZ bar or dumbbells", ["Triceps"], "A lying elbow-extension movement lowering weight toward the head.", 3, 10, 75),
        e(49, "Plank", ["Front Plank"], .core, "Bodyweight", ["Core"], "An isometric bracing hold supported on the forearms or hands.", 3, 1, 60, .timed(defaultSeconds: 30)),
        e(50, "Side Plank", [], .core, "Bodyweight", ["Obliques", "Core"], "A lateral isometric hold supported on one arm.", 3, 1, 60, .timed(defaultSeconds: 30)),
        e(51, "Dead Bug", [], .core, "Bodyweight", ["Core"], "A supine trunk-control drill alternating opposite arms and legs.", 3, 10, 45, .bodyweight),
        e(52, "Hanging Leg Raise", [], .core, "Pull-up bar", ["Core", "Hip Flexors"], "A hanging movement raising the legs under control.", 3, 10, 75, .bodyweight),
        e(53, "Cable Crunch", [], .core, "Cable machine", ["Abdominals"], "A kneeling loaded spinal-flexion movement.", 3, 12, 60),
        e(54, "Pallof Press", [], .core, "Cable or resistance band", ["Core", "Obliques"], "An anti-rotation press performed perpendicular to the resistance.", 3, 10, 60),
        e(55, "Ab Wheel Rollout", ["Ab Rollout"], .core, "Ab wheel", ["Core"], "A kneeling rollout that challenges trunk extension control.", 3, 8, 75, .bodyweight),
        e(56, "Hack Squat", [], .legs, "Hack squat machine", ["Quadriceps", "Glutes"], "A machine squat with the torso supported against an angled pad.", 3, 10, 120),
        e(57, "Smith Machine Squat", ["Smith Squat"], .legs, "Smith machine", ["Quadriceps", "Glutes"], "A squat performed on a barbell fixed to vertical guide rails.", 3, 8, 120),
        e(58, "Belt Squat", [], .legs, "Belt squat machine", ["Quadriceps", "Glutes"], "A squat loaded through a hip belt to reduce loading on the spine.", 3, 10, 120),
        e(59, "Step-Up", ["Dumbbell Step-Up"], .legs, "Bench or box", ["Quadriceps", "Glutes"], "A unilateral movement stepping onto an elevated surface under control.", 3, 8, 90),
        e(60, "Glute Bridge", [], .legs, "Bodyweight or barbell", ["Glutes", "Hamstrings"], "A floor-based hip extension with the shoulders and feet supported.", 3, 12, 75),
        e(61, "Good Morning", [], .legs, "Barbell", ["Hamstrings", "Glutes", "Back"], "A barbell hip hinge performed with a soft knee bend and neutral spine.", 3, 8, 120),
        e(62, "Single-Leg Romanian Deadlift", ["Single-Leg RDL"], .legs, "Dumbbell or kettlebell", ["Hamstrings", "Glutes"], "A unilateral hip hinge that also challenges balance and hip stability.", 3, 8, 90),
        e(63, "Nordic Hamstring Curl", ["Nordic Curl"], .legs, "Bodyweight", ["Hamstrings"], "A kneeling bodyweight curl that resists the torso lowering toward the floor.", 3, 6, 120, .bodyweight),
        e(64, "Cable Pull-Through", [], .legs, "Cable machine", ["Glutes", "Hamstrings"], "A cable-resisted hip hinge with the rope passing between the legs.", 3, 12, 75),
        e(65, "Hip Abduction", ["Machine Hip Abduction"], .legs, "Hip abduction machine", ["Glutes", "Hip Abductors"], "A seated machine movement pressing the knees outward.", 3, 15, 60),
        e(66, "Hip Adduction", ["Machine Hip Adduction"], .legs, "Hip adduction machine", ["Adductors"], "A seated machine movement drawing the knees inward.", 3, 15, 60),
        e(67, "Donkey Calf Raise", [], .legs, "Machine", ["Calves"], "A bent-over straight-leg calf raise emphasizing a deep ankle stretch.", 3, 12, 60),
        e(68, "Seated Calf Raise", [], .legs, "Seated calf machine", ["Calves"], "A bent-knee calf raise performed with resistance over the thighs.", 3, 15, 60),
        e(69, "Dumbbell Fly", ["Flat Dumbbell Fly"], .chest, "Dumbbells", ["Chest"], "A flat-bench chest fly moving the arms through a wide arc.", 3, 12, 60),
        e(70, "Pec Deck", ["Machine Fly", "Machine Chest Fly"], .chest, "Pec deck machine", ["Chest"], "A supported machine fly bringing the upper arms together.", 3, 12, 60),
        e(71, "Decline Bench Press", [], .chest, "Barbell", ["Chest", "Triceps"], "A barbell press performed on a declined bench.", 3, 8, 120),
        e(72, "Close-Grip Bench Press", [], .chest, "Barbell", ["Triceps", "Chest"], "A bench press using a narrower grip to emphasize elbow extension.", 3, 8, 120),
        e(73, "Floor Press", [], .chest, "Barbell or dumbbells", ["Chest", "Triceps"], "A horizontal press from the floor that limits shoulder extension.", 3, 8, 90),
        e(74, "Kneeling Push-Up", ["Modified Push-Up"], .chest, "Bodyweight", ["Chest", "Triceps"], "A push-up performed with the knees supported to reduce resistance.", 3, 10, 60, .bodyweight),
        e(75, "Wide-Grip Pull-Up", [], .back, "Pull-up bar", ["Lats", "Upper Back"], "A pronated pull-up performed with the hands wider than shoulder width.", 3, 6, 120, .bodyweight),
        e(76, "Neutral-Grip Pull-Up", [], .back, "Pull-up bar", ["Lats", "Biceps"], "A vertical bodyweight pull using parallel handles and a neutral grip.", 3, 6, 120, .bodyweight),
        e(77, "Machine Row", [], .back, "Row machine", ["Upper Back", "Lats"], "A guided horizontal pull performed on a plate- or stack-loaded machine.", 3, 10, 90),
        e(78, "Pendlay Row", [], .back, "Barbell", ["Upper Back", "Lats"], "A strict barbell row beginning from a dead stop on the floor each rep.", 3, 6, 120),
        e(79, "Meadows Row", ["Landmine Row"], .back, "Landmine and barbell", ["Lats", "Upper Back"], "A staggered-stance one-arm row using the end of a landmine barbell.", 3, 10, 90),
        e(80, "Dumbbell Pullover", [], .back, "Dumbbell and bench", ["Lats", "Chest"], "A lying shoulder-extension movement lowering one dumbbell behind the head.", 3, 10, 75),
        e(81, "Rack Pull", [], .back, "Barbell and rack", ["Back", "Glutes"], "A shortened-range deadlift beginning with the bar elevated on safety pins.", 3, 5, 150),
        e(82, "Dumbbell Shrug", ["Shrug"], .back, "Dumbbells", ["Traps"], "A loaded shoulder elevation performed while standing tall.", 3, 12, 60),
        e(83, "Upright Row", [], .shoulders, "Barbell or cable", ["Side Delts", "Traps"], "A vertical pull raising the elbows while keeping the load close to the torso.", 3, 10, 75),
        e(84, "Machine Shoulder Press", [], .shoulders, "Shoulder press machine", ["Shoulders", "Triceps"], "A guided seated vertical pressing movement.", 3, 10, 90),
        e(85, "Dumbbell Front Raise", ["Front Raise"], .shoulders, "Dumbbells", ["Front Delts"], "A shoulder-flexion movement raising dumbbells in front of the body.", 3, 12, 60),
        e(86, "Landmine Press", [], .shoulders, "Landmine and barbell", ["Shoulders", "Chest", "Triceps"], "An angled one-arm press using the anchored end of a barbell.", 3, 10, 75),
        e(87, "Band Pull-Apart", [], .shoulders, "Resistance band", ["Rear Delts", "Upper Back"], "A straight-arm band pull that draws the hands apart across the chest.", 3, 15, 45, .bodyweight),
        e(88, "Zottman Curl", [], .arms, "Dumbbells", ["Biceps", "Forearms"], "A curl with palms up on the lift and palms down on the lower.", 3, 10, 60),
        e(89, "Incline Dumbbell Curl", ["Incline Curl"], .arms, "Dumbbells and incline bench", ["Biceps"], "A dumbbell curl performed seated with the arms extended behind the torso.", 3, 10, 60),
        e(90, "Concentration Curl", [], .arms, "Dumbbell", ["Biceps"], "A seated single-arm curl with the elbow braced against the inner thigh.", 3, 10, 60),
        e(91, "Reverse Curl", [], .arms, "Barbell or EZ bar", ["Forearms", "Brachialis"], "An elbow curl performed with a pronated, palms-down grip.", 3, 10, 60),
        e(92, "Cable Overhead Triceps Extension", ["Rope Overhead Extension"], .arms, "Cable machine", ["Triceps"], "An overhead cable elbow extension commonly performed with a rope attachment.", 3, 12, 60),
        e(93, "Triceps Kickback", ["Dumbbell Kickback"], .arms, "Dumbbell", ["Triceps"], "A hinged single-arm elbow extension with the upper arm held by the torso.", 3, 12, 60),
        e(94, "Diamond Push-Up", ["Close-Grip Push-Up"], .arms, "Bodyweight", ["Triceps", "Chest"], "A push-up performed with the hands close together beneath the chest.", 3, 8, 75, .bodyweight),
        e(95, "Bicycle Crunch", [], .core, "Bodyweight", ["Core", "Obliques"], "An alternating crunch bringing each elbow toward the opposite knee.", 3, 16, 45, .bodyweight),
        e(96, "Reverse Crunch", [], .core, "Bodyweight", ["Abdominals"], "A supine curl lifting the pelvis toward the rib cage.", 3, 12, 45, .bodyweight),
        e(97, "Russian Twist", [], .core, "Bodyweight or medicine ball", ["Obliques", "Core"], "A seated rotation moving the hands from side to side while bracing the trunk.", 3, 16, 45, .bodyweight),
        e(98, "Bird Dog", [], .core, "Bodyweight", ["Core", "Glutes"], "A quadruped stability drill extending the opposite arm and leg.", 3, 10, 45, .bodyweight),
        e(99, "Mountain Climber", [], .core, "Bodyweight", ["Core", "Hip Flexors"], "A plank movement alternating knee drives toward the chest.", 3, 20, 45, .bodyweight),
        e(100, "Farmer Carry", ["Farmer's Walk"], .core, "Dumbbells or kettlebells", ["Grip", "Core", "Traps"], "A loaded carry performed while walking tall with a weight in each hand.", 3, 1, 60, .timed(defaultSeconds: 30)),
        e(101, "Assisted Pull-Up Machine", ["Assisted Pull-Up"], .back, "Assisted pull-up machine", ["Lats", "Upper Back", "Biceps"], "A pull-up performed with counterweight assistance from a machine.", 3, 8, 120, .assisted),
        e(102, "Machine Biceps Curl", ["Machine Curl"], .arms, "Biceps curl machine", ["Biceps"], "A guided elbow curl performed with the upper arms supported by the machine.", 3, 10, 75)
    ]

    private static func e(
        _ id: Int,
        _ name: String,
        _ aliases: [String],
        _ category: ExerciseCategory,
        _ equipment: String,
        _ muscles: [String],
        _ description: String,
        _ sets: Int,
        _ reps: Int,
        _ rest: Int,
        _ modality: CatalogExerciseModality = .weighted
    ) -> CatalogExercise {
        CatalogExercise(
            id: id,
            name: name,
            aliases: aliases,
            category: category,
            equipment: equipment,
            muscles: muscles,
            description: description,
            defaultSets: sets,
            defaultReps: reps,
            defaultRestSeconds: rest,
            modality: modality
        )
    }
}
