globals [
  Total_forage_colony_A
  Total_forage_colony_B
  ants
  disease_in_colony_A?
  spillover_in_colony_A
  max_infected_A
  max_infected_B
  time_to_peak_A
  time_to_peak_B
  pop_max_infA
  pop_max_infB
  final_suceptible_A
  final_suceptible_B
  run_avg_infected_A
  run_avg_infected_B
  cum_infected_A
  cum_infected_B
  data_counter
  final_PopA
  final_PopB
  diffusion-rate
  evaporation-rate
  territory-size-ratio-A-to-B
]
patches-own [
  chemical-A             ;; amount of chemical A on this patch
  chemical-B             ;; amount of chemical B on this patch
  food                 ;; amount of food on this patch (0, 1, or 2)
  nestA?                ;; true on nest patches, false elsewhere
  nestB?                ;; true on nest patches, false elsewhere
  nest-scentA           ;; number that is higher closer to the nest
  nest-scentB           ;; number that is higher closer to the nest
  food-source-number   ;; number (1, 2, or 3) to identify the food sources
  territoryA?         ;; defensible territory for species A
  territoryB?         ;; defensible territory for species B
]

turtles-own [
    nest-id              ;; index of colony residence (1 for colony A or 2 for colony B)
    nearest-neighbor     ;; agent set of nearest neighbors to a focal ant
    infected?            ;; health status of the ant (boolean: 0 or 1)
    susceptible?        ;; tracks whether the ant was initially susceptible
    inbound?            ;; tracks whether ant is currently returning food to its home nest (boolean: 0 if false, 1 if true).
  ]


;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-population
  setup-infected
  setup-patches
  reset-ticks
end

to setup-population

  set-default-shape turtles "bug"
  let n 2 ; number of colonies

  create-turtles n * starting-colony-size; create a population of ant workers
  [ set size 2
    set infected? false
    set susceptible? true
    set inbound? false ; ants are leaving the nest in search of food
    set color violet
    set nest-id 1 ; assign workers to colony A (resident)
    setxy -35 35; ants are located at the top-left corner of the world

  ]

  ask n-of starting-colony-size turtles
  [set color yellow
    set nest-id 2 ;re-assign some workers to colony B (invader)
    setxy 35 -35 ;ants are moved to the bottom-right corner of the world
  ]
  ;the number of workers in colony A and B is equal to starting-colony-size


  ;Simulating ant foraging
  ;Ants search for food using sensory information obtained from the environment. When an ant finds a piece of food, it carries the food back to the nest, dropping a chemical as it moves.
  ;When other ants "sniff" the chemical, they follow the chemical toward the food. As more ants carry food to the nest, they reinforce the chemical trail.
  ;To reduce the complexity of our simulation environment, we assumed that chemical pheremone is highly volatile.
  ;This condition is captured by the following simulation parmeters:

   set diffusion-rate 1 ; low diffusibility
   set evaporation-rate 99; high evaporation rate


end

to setup-infected
  ask n-of initial-infected turtles with [nest-id = 2][
   set infected? true  ;an ant is chosen from colony 2 is designated as 'infectious'
   set susceptible? false; infected ants are not longer suceptible
  ]

  ;;initialize variables to store infection data during simulations

 set max_infected_A (count turtles with [nest-id = 1 and infected? = true])
 set max_infected_B (count turtles with [nest-id = 2 and infected? = true])
 set cum_infected_A max_infected_A
 set cum_infected_B max_infected_B
 set run_avg_infected_A 0
 set run_avg_infected_B 0
 set disease_in_colony_A? false
 set spillover_in_colony_A 0
end

to setup-patches
  ask patches
  [ setup-nest
    setup-food
    recolor-patch ]
end


to setup-nest  ;; patch procedure

  ;Simulating ant territories
  ;We simulated the terrirtorial behavior of a trail-laying ant species.
  ;Territoriality (here defined as the exclusion of non-colony members from a well-defined area around the nest)
  ;could limit colony-level risks from infectious diseases by reducing contacts with infected individuals outside the nest.
  ;To reduce model complexity, we assume that that territorial boundaries are maintained via recognition and aviodance.
  ;A colony's territory extend beyond its nest and ends in an area where food is likely to occur.

  set territory-size-ratio-A-to-B 1; colony A and colony B defend a territoriy of roughly equal size

  set nestA? (distancexy -35 35) < 5; set nest? variable to true inside the nest, false elsewhere
  set nestB? (distancexy 35 -35) < 5
  set territoryA? (distancexy -35 35) < territory-size-ratio-A-to-B * 40 ; Colony A (resident)
  set territoryB? (distancexy 35 -35) < 40; Colony B (invader)

  ;; spread a nest-scent over the whole world -- stronger near the nest
  set nest-scentA 200 - distancexy -35 35
  set nest-scentB 200 - distancexy 35 -35
end

to setup-food  ;; patch procedure
  ;; setup food source one on the right
  if (distancexy (0.6 * max-pxcor) (0.6 * max-pycor)) < 5
  [ set food-source-number 1 ]
  ;; setup food source two on the lower-left
  if (distancexy (-0.6 * max-pxcor) (-0.6 * max-pycor)) < 5
  [ set food-source-number 2 ]
  ;; setup food source three in the center
  if (distancexy (0.0 * max-pxcor) (0.0 * max-pycor)) < 5
  [ set food-source-number 3 ]
  ;; set "food" at sources to either 1 or 2, randomly
  if food-source-number > 0
  [ set food initial-resource-abundance ]
end



to recolor-patch  ;; patch procedure
  ;; give color to nest and food sources

  ifelse nestA?
  [ set pcolor violet ]
       [  ifelse nestB? [set pcolor yellow - 0.5]
             [
       ifelse food > 0
    [ if food-source-number = 1 [ set pcolor green - 2 ] ;cyan
      if food-source-number = 2 [ set pcolor green - 2  ] ; sky
      if food-source-number = 3 [ set pcolor green - 2 ] ] ; blue
    [ifelse territoryA? [set pcolor violet + 4]
      [ifelse territoryB? [set pcolor yellow + 4]

    ;; scale color to show chemical concentration
    [ set pcolor scale-color green max list chemical-A chemical-B 0.1 5 ]


    ]]]]



end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  ;the simulation continues until one of the following events occur
  ;(i) The epidemic ends - there are no infected ants
  ;(ii) The resource stock is fully depleted  - there are no more food items to find the landscape
  ;(iii) Colony A goes extinct - there are no more worker ants from colony A
  ;(iv) Colony B goes extinct - there are no more worker ants from colony B

  if (all? turtles [ not infected? ] or sum [food] of patches = 0 or count turtles with [nest-id = 1] = 0 or count turtles with [nest-id = 2] = 0)
  [
   set final_suceptible_A count turtles with [nest-id = 1 and infected? = false and susceptible? = true ]
   set final_suceptible_B count turtles with [nest-id = 2 and infected? = false and susceptible? = true ]
   set final_PopA count turtles with [nest-id = 1]
   set final_PopB count turtles with [nest-id = 2]
   stop
  ]

  do-movement ; ants move around in search of food - successful ants retrive food and head towards their home nest - unsucessful ants may wander into the territory of a neighbor colony and become 'integrated'

  infect-susceptibles

  remove-infected

  ;ask turtles
  ;[move] ; ants move around in search of food - successful ants retrive food and head towards their home nest - unsucessful ants may wander into the territory of a neighbor colony and become 'integrated'

  if disease-type? = "SID" [do-colony-demography]

  ;do-colony-demography

  if (show-infection-location? = false) [update-patches]

  calculate-max-infected-A

  calculate-max-infected-B

  tick ; advance time by 1 unit
end


to do-movement
  ask turtles [
if (who >= ticks)
    [ stop ] ;; delay initial departure

    ;ifelse (color != orange + 1)
  ifelse(inbound? = false)
    [ look-for-food  ]       ;; not carrying food? look for it
     [
      ifelse (nest-id = 1)
      [return-to-nestA] ;; carrying food? take it back to nest
      [return-to-nestB]
     ]

    wiggle ;randomize ant's heading

  if (nest-id = 1 and territoryB? = true)
    [
      let p foreign-worker-rejection-probability ;alien worker drifts into colony B
      ifelse (random-float 1.0 <  p)
      [rt 180 uphill-nest-scentA]
      [if (integrate-foreign-workers? = true)[set nest-id 2 set color yellow]]; if true, worker turns around and set heading towards colony A. If false, she gets adopted into colony B
    ]

  if (nest-id = 2 and territoryA? = true)
    [
      let p foreign-worker-rejection-probability ;alien worker drifts into colony A
      ifelse (random-float 1.0 <  p)
      [lt 180 uphill-nest-scentB]
      [
        if (integrate-foreign-workers? = true)
        [set nest-id 1 set color violet
          if (infected? and disease_in_colony_A? = false)
          [set disease_in_colony_A? true set spillover_in_colony_A ticks  ]; if true, worker turns around and set heading towards colony B. If false, she gets adopted into colony A
        ]
     ]
  ]

fd 1 ; step forward
  ]

end

to infect-susceptibles

  ifelse (infect-outside-territory? = true )
  [set ants turtles]
  [set ants turtles-on patches with [territoryA? = true or territoryB? = true]]

  ask ants with [infected? = false and susceptible? = true]
  [
    let infected-neighbors (count other turtles-here with [infected? = true] ) ; susceptible ants make contact wth neighbors - infectious contacts are restricted to ants on the same patch as the focal ant

    if (random-float 1 <  1 - (((1 - transmissibility) ^ infected-neighbors))); prob. of infection = 1 - (prob. of failed transmission)^{# of social contacts}
    [
      set infected? true
      set susceptible? false
      if do-color-for-figure? = true [set color red]

      if (disease_in_colony_A? = false  and nest-id = 1)
      [
        set spillover_in_colony_A ticks ;stores timestep when disease is introduced into colony A
        set disease_in_colony_A? true
      ]

      ask patch-here [set pcolor red]; records patch where infection occured

    ]
  ]
end

to remove-infected
  ask turtles with [infected? = true]
  [
    let x removal-rate
    if (random-float 1 < x)
    [
      set infected? false
      set susceptible? true

      if (disease-type? = "SID")
      [
        die ;Unlike the SIS model, the ant dies immediately after 'recovery'
      ]
    ]
  ]

end

to do-colony-demography
  add-new-workers
  cull-excess-workers
end


to add-new-workers

 let r population-replacement-pct * starting-colony-size / 100; how many ants will be added to each colony

  if (ticks > 0 and ticks mod length-of-replacement-cycle = 0 and count turtles < 300)
  [
  create-turtles r ;colony A (resident)
    [set size 2
    set infected? false
    set susceptible? true
    set color violet
    set nest-id 1
    setxy -35 35
    ]

 create-turtles r ;colony B (invader)
  [ set size 2
    set infected? false
    set susceptible? true
    set color yellow
    set nest-id 2
    setxy 35 -35
    ]
  ]

end

to cull-excess-workers

  let r population-replacement-pct * starting-colony-size / 100 ;how many ants will be removed from each colony

  if (ticks > 0 and ticks mod length-of-replacement-cycle = 0)
  [

  let c1 min (list r count turtles with [nest-id = 1])
  let c2 min (list r count turtles with [nest-id = 2])

  ask n-of c1 turtles with [nest-id = 1]
    [die]

  ask n-of c2 turtles with [nest-id = 2]
    [die]

  ]

end

to update-patches
    diffuse chemical-A (diffusion-rate / 100)
    diffuse chemical-B (diffusion-rate / 100)
  ask patches
  [ set chemical-A chemical-A * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical
    set chemical-B chemical-B * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical
    recolor-patch
  ]

   if do-color-for-figure? = true [ask patches with [pcolor = 50] [set pcolor white]]
end

;;HELPER PROCEDURES
to look-for-food  ;; turtle procedure
  if (food > 0)
  [ ;set color orange + 1     ;; pick up food
    set food food - 1        ;; and reduce the food source
    rt 180                   ;; and turn around
    set inbound? true        ;; update foraging status
    stop
  ]

  ;; go in the direction where the chemical smell is strongest
  ifelse (nest-id = 1)
  [
  if (chemical-A >= 0.05) and (chemical-A < 2)
    [ uphill-chemical-A ]
  ]
  [
    if (chemical-B >= 0.05) and (chemical-B < 2)
    [ uphill-chemical-B ]
  ]


end

;; sniff left and right, and go where the strongest smell is
to uphill-chemical-A  ;; turtle procedure
  let scent-ahead chemical-scent-at-angle-A   0
  let scent-right chemical-scent-at-angle-A  45
  let scent-left  chemical-scent-at-angle-A -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse (scent-right > scent-left)
    [ rt 45 ]
    [ lt 45 ] ]

end

to uphill-chemical-B  ;; turtle procedure
  let scent-ahead chemical-scent-at-angle-B   0
  let scent-right chemical-scent-at-angle-B  45
  let scent-left  chemical-scent-at-angle-B -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse (scent-right > scent-left)
    [ rt 45 ]
    [ lt 45 ] ]

end

to return-to-nestA  ;; turtle procedure
  ifelse (nestA?)
  [ ;; drop food and head out again
    set Total_forage_colony_A Total_forage_colony_A + 1
    set color violet
    set inbound? false        ;; update foraging status
    rt 180 ]
  [ set chemical-A chemical-A + 60  ;; drop some chemical
    uphill-nest-scentA ]         ;; head toward the greatest value of nest-scent
end


to return-to-nestB  ;; turtle procedure
  ifelse (nestB?)
  [ ;; drop food and head out again
    set Total_forage_colony_B Total_forage_colony_B + 1
    set color yellow
    set inbound? false        ;; update foraging status
    rt 180 ]
  [ set chemical-B chemical-B + 60  ;; drop some chemical
    uphill-nest-scentB ]         ;; head toward the greatest value of nest-scent
end


;; sniff left and right, and go where the strongest smell is
to uphill-nest-scentA  ;; turtle procedure
  let scent-ahead nest-scent-at-angleA   0
  let scent-right nest-scent-at-angleA  45
  let scent-left  nest-scent-at-angleA -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse (scent-right > scent-left)
    [ rt 45 ]
    [ lt 45 ] ]
end

to uphill-nest-scentB  ;; turtle procedure
  let scent-ahead nest-scent-at-angleB   0
  let scent-right nest-scent-at-angleB  45
  let scent-left  nest-scent-at-angleB -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse (scent-right > scent-left)
    [ rt 45 ]
    [ lt 45 ] ]
end

to wiggle  ;; turtle procedure
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to-report nest-scent-at-angleA [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scentA] of p
end

to-report nest-scent-at-angleB [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scentB] of p
end

to-report chemical-scent-at-angle-A [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical-A] of p
end

to-report chemical-scent-at-angle-B [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical-B] of p
end

to calculate-max-infected-A
  let x count turtles with [nest-id = 1 and infected? = true]
  if (x > max_infected_A)
  [
   set max_infected_A x set time_to_peak_A ticks
   set pop_max_infA count turtles with [nest-id = 1]
  ]
end

to calculate-max-infected-B
  let x count turtles with [nest-id = 2 and infected? = true]
  if (x > max_infected_B)
  [
   set max_infected_B x set time_to_peak_B ticks
   set pop_max_infB count turtles with [nest-id = 2]
  ]
end


; Copyright 1997 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
456
10
1128
683
-1
-1
9.352113
1
10
1
1
1
0
0
0
1
-35
35
-35
35
1
1
1
ticks
30.0

BUTTON
87
215
167
248
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
171
215
246
248
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
81
94
284
127
starting-colony-size
starting-colony-size
50
100
50.0
1.0
1
ants
HORIZONTAL

PLOT
1225
394
1468
565
Resoruce abundance
time
food
0.0
50.0
0.0
120.0
true
false
"" ""
PENS
"food-in-pile1" 1.0 0 -13840069 true "" "plotxy ticks sum [food] of patches with [pcolor = green - 2]"
"food-in-pile2" 1.0 0 -10141563 true "" ";plotxy ticks sum [food] of patches with [pcolor = sky]\n"
"food-in-pile3" 1.0 0 -1184463 true "" ";plotxy ticks sum [food] of patches with [pcolor = blue]"

MONITOR
1222
346
1369
391
Total forage
Total_forage_colony_A
17
1
11

MONITOR
1372
346
1506
391
Total forage
Total_forage_colony_B
17
1
11

SLIDER
81
307
253
340
initial-infected
initial-infected
1
10
1.0
1
1
ants
HORIZONTAL

PLOT
1164
19
1517
287
Disease prevalance
time
Proportion infected
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Colony A (resident)" 1.0 0 -11783835 true "" "plot count turtles with [nest-id = 1 and infected? = true]/ (count turtles with [nest-id = 1])"
"Colony B (invader)" 1.0 0 -4079321 true "" "plot count turtles with [nest-id = 2 and infected? = true]/ (count turtles with [nest-id = 2])"

SLIDER
81
345
253
378
transmissibility
transmissibility
0.005
0.25
0.2
0.00125
1
NIL
HORIZONTAL

SLIDER
83
133
372
166
foreign-worker-rejection-probability
foreign-worker-rejection-probability
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
81
385
253
418
removal-rate
removal-rate
0.001
0.001
0.001
0.001
1
NIL
HORIZONTAL

SLIDER
79
55
426
88
initial-resource-abundance
initial-resource-abundance
10
25
10.0
5
1
food items per patch
HORIZONTAL

SWITCH
79
425
288
458
infect-outside-territory?
infect-outside-territory?
0
1
-1000

SWITCH
86
173
312
206
integrate-foreign-workers?
integrate-foreign-workers?
1
1
-1000

MONITOR
1249
300
1345
345
Resident ants
count turtles with [nest-id = 1]
17
1
11

MONITOR
1386
298
1475
343
Invader ants
count turtles with [nest-id = 2]
17
1
11

SLIDER
73
501
306
534
population-replacement-pct
population-replacement-pct
0
60
60.0
5
1
%
HORIZONTAL

SLIDER
76
543
341
576
length-of-replacement-cycle
length-of-replacement-cycle
100
300
300.0
50
1
ticks
HORIZONTAL

CHOOSER
81
255
219
300
disease-type?
disease-type?
"SIS" "SID"
0

SWITCH
79
464
291
497
show-infection-location?
show-infection-location?
1
1
-1000

SWITCH
78
597
265
630
do-color-for-figure?
do-color-for-figure?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

This project explores the evolutionary significance of territoriality in social insects as a potential form of collective defense against infectious diseases.  We used an agent-based simulation modeling approach to test whether the monopolization of space for resource foraging could efficiently neutralize the spread of a novel infection among established colonies of social insects. Our analyses help clarify the conditions under which territorial behaviors might confer an evolutionary advantage in a population or species under threat from pathogens. 


## HOW IT WORKS

We have modified the Netlogo Ant foraging simulation (Wilensky, 1997) to study how territorial behaviors can affect the spread of infections among a pair of neighboring colonies. A key parameter of the model is the population’s effectiveness at maintaining its territorial boundary. To simplify this model, we assume that ant colony territories are maintained by recognition and avoidance behavior of conspecifics (nestmates) and heterospecifics (non-nestmates). In other words, we assume that each ant can recognize its own colony’s territory and avoids entering territory of neighboring colonies. The dimensions of the controllable region (i.e., territory) are the same for both colonies.
 
In the simulation, ants search for patchily distributed resources on a landscape. Each ant uses chemical pheromones to locate and exploit food sources. When an ant finds a piece of food, it carries the food back to the nest, dropping a chemical as it moves. When other ants "sniff" the chemical, they follow the chemical toward the food. As more ants carry food to the nest, they reinforce the chemical trail.


To determine whether territorial behaviors can efficiently control the spread of an infectious disease, we used a standard mathematical model, the S-I epidemic model.   The S-I model describes the transmission dynamics of a pathogen that spreads from individual to individual via close social contact. The simulation allows for an investigation of pathogens that cause transient, non-lethal infections (i.e., the SIS model - infected ants can recover but recovery does not confer immunity) or pathogens that causes chronic and lethal infections (i.e., the SID model – infected ants remains infectious until their death). 

To capture realistic colony population dynamics under the SID parameter condition, the model simulates a stylized process of demographic change due to “cohort replacement.” During cohort replacement, a fixed number of colony workers (individually pulled from a uniform distribution) are removed from the workforce and the same number is added as new workers.  The share of population that is replaced is a constant percentage (POPULATION-REPLACEMENT-PCT) of the initial population (STARTING-COLONY-SIZE). Cohort replacement occurs at scheduled time steps during a simulation. The demographic schedule is set by a single parameter (LENGTH-OF-REPLACEMENT-CYCLE) that sets the frequency of cohort replacement. 


## HOW TO USE IT

Click the SETUP button to set up the ant nests (in violet and yellow, at the top left and bottom right corners of the arena) and three piles of food (in green, at the center). Click the GO button to start the simulation.
 
If you want to change the number of food items, move the INITIAL-RESOURCE-ABUNDANCE slider before pressing SETUP.
 
If you want to change the number of ants, move the STARTING-COLONY-SIZE slider before pressing SETUP.
 
The FOREIGN-WORKER-REJECTION-PROBABILITY slider controls the probability that a foreign worker repelled at the territorial border.
 
The INTEGRATE-FOREIGN-WORKERS? switch controls whether a colony can accept foreign ants (i.e., heterospecifics) into its workforce. 
 
The DISEASE-TYPE? selector allows for the simulation of a infectious disease following an SIS (susceptible-infected-susceptible) or SID (susceptible-infected-dead) transmission pattern.
 
The INITIAL-INFECTED slider controls the initial number of ants that have the disease.
 
The TRANSMISSIBILITY slider controls the contagiousness of the pathogen.
 
The REMOVAL-RATE slider controls the rate at which infected ants are removed from the population. In the SIS model, removal describes the spontaneous recovery of infected ants due to within-colony processes generating social immunity (e.g., allogrooming by nestmates). In the SID model, removal describes the spontaneous mortality of infected ants due to disease (e.g., death before expected life expectancy).
 
The INFECT-OUTSIDE-TERRITORY? switch controls whether the disease can be transmitted from social contacts that occur outside territorial spaces. When this switch is off, infections can only occur from contacts that occur within a colony’s territory.
 
The SHOW-INFECTION-LOCATION? switch helps visualize infection hotspots on the landscape. When this switch is on, the simulation tracks the spatial locations (patches) where a disease transmission event has occurred and visualizes these locations in red color.


The simulation generates data on four metrics at the end of each run: (i) maximum disease prevalence, (ii) time step when infection spillover occurred, (iii) number of remaining susceptibles, and (iv) total amount of food items collected by colony A and colony B.


## HOW TO CITE

If you mention this model in a publication, we ask that you include these citations for the model itself and for the NetLogo software:

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was developed at the MIT Media Lab using CM StarLogo.  See Resnick, M. (1994) "Turtles, Termites and Traffic Jams: Explorations in Massively Parallel Microworlds."  Cambridge, MA: MIT Press.  Adapted to StarLogoT, 1997, as part of the Connected Mathematics Project.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 1998.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Impact_of_territorial_integrity" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>max_infected_A</metric>
    <metric>max_infected_B</metric>
    <metric>time_to_peak_A</metric>
    <metric>time_to_peak_B</metric>
    <metric>final_suceptible_A</metric>
    <metric>final_suceptible_B</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="1"/>
      <value value="99"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alien-detection-probability">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Impact_of_transmissibility" repetitions="40" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>max_infected_A</metric>
    <metric>max_infected_B</metric>
    <metric>time_to_peak_A</metric>
    <metric>spillover_in_colony_A</metric>
    <metric>final_suceptible_A</metric>
    <metric>final_suceptible_B</metric>
    <metric>final_PopA</metric>
    <metric>final_PopB</metric>
    <metric>Total_forage_colony_A</metric>
    <metric>Total_forage_colony_B</metric>
    <metric>pop_max_infA</metric>
    <metric>pop_max_infB</metric>
    <enumeratedValueSet variable="transmissibility">
      <value value="0.005"/>
      <value value="0.01"/>
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="foreign-worker-rejection-probability">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Impact of drift" repetitions="60" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>max_infected_A</metric>
    <metric>max_infected_B</metric>
    <metric>time_to_peak_A</metric>
    <metric>time_to_peak_B</metric>
    <metric>final_suceptible_A</metric>
    <metric>final_suceptible_B</metric>
    <metric>final_PopA</metric>
    <metric>final_PopB</metric>
    <metric>Total_forage_colony_A</metric>
    <metric>Total_forage_colony_B</metric>
    <metric>pop_max_infA</metric>
    <metric>pop_max_infB</metric>
    <enumeratedValueSet variable="worker-adoption">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alien-detection-probability">
      <value value="0"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
