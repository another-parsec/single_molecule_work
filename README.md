# single_molecule_work

This is a MATLAB applet to visualize/sort through flourescent intensities of single molecule traces over time. The idea is to track the colocalization of freely moving molecules that are flourescently labelled with non-moving DNA "spots" (also floruescently labeled) that are fixed to a glass coverslip. The area covered by these DNA spots on the coverslips are too large to fit in one view and so multiple images across slide are taken (fields of view). These slide is also images over time to capture the dynamics of these molecular movements and to determine the length of flourescent colocalizations (potential interactions). 

Only works with single molecule CSV files that contain the string "smf" in their title in order for the program to recognize and attempt to open the file. An example file of this type is in this repository. 


The SMF(single molecule format) data consists of the following structure. 

| field of view id | fixed spot id | fixed spot x coordinate | fixed spot y coordinate | signal channel index | signal spot intensity | px distance from fixed spot to signal spot | background intensity around signal spot |
|------------------|---------------|-------------------------|-------------------------|----------------------|------------------|--------------------------------------------|-----------------------------------------|

The first 5 columns are fixed. Any additional columns (in pairs of 3) represent a captured frame (moment in time) which contains data on the intensity of a flourescent signal spot in a particular channel, how close that signal was to the fixed spot (in pixels), and the background intensity of signal surrounding that spot. In other words, going across a row is equivalent to going through time and tracking signals coming and going from a particular fixed spot. 
