source mad-lab-lib/mad-lab-lib.tcl



proc fx_rtheta { radius theta } {
    set x [expr { round( $radius * cos( $theta ) ) } ]
}

proc fy_rtheta { radius theta } {
    set y [expr { round( $radius * sin( $theta ) ) } ]
}

# parabola with focal point at 0,f
#  y = pow(x,2.) / ( f * 4. )


proc f_y { x focal_point_factor } {
    set y [expr { pow($x,2.) / ${focal_point_factor} }  ]
}

# units are in pixels, 72px/inch
# approx 225 px / inch or 72 pt, or 28px per 9pt

# set to width of antenna:
set x_max_inches [expr { 8 * 12 } ]
# set to depth of antenna:
set y_max_inches [expr { 1 * 12 } ]
set x_min 0
set y_min 0

set x_max [expr { $x_max_inches * 72 } ]
set y_max [expr { $y_max_inches * 72 } ]
set x_midpoint [expr { $x_max / 2. } ]
set y_midpoint [expr { $y_max / 2. } ]

set o_x [expr { ( $x_max - $x_min ) / 2 } ]
set o_y [expr { ( $y_max - $y_min ) / 2 } ]

set new_file parabola-${x_max}x${y_max}.png
mml_new_filename $new_file $x_max $y_max

# Focal point is at depth of antenna
# Multiply it by a number > 1 to put focal point outside of antenna
# Multiply it by a number < 1 to put focal point inside antenna
set focal_point [expr { $y_max } ]
set k [expr { 4. * $focal_point } ]
puts "If diffusion is Gaussian distribution with 80% at 18deg,"
puts "then 80% of reflection is approximately within"



set pi [expr { acos(0) * 2. } ]
set pi2 [expr { 2. * $pi } ]
set halfpi [expr { $pi / 2. } ]
set quartpi [expr { $pi / 4. } ]
set sqrt2 [expr { sqrt(2) } ]
set white "#ffffff"
set skyblue "#66ccff"
set red "#ff0000"
set black "#000000"


set radius [expr { round( $y_max_inches * sin( 18. * $pi / 180.) * 10 ) / 20. }]
puts "$radius inches of focal point."



# alpha is angle between x-axis and page normal to view.
set alpha $quartpi
set sin_alpha [expr { sin( $alpha ) } ]
set cos_alpha [expr { cos( $alpha ) } ]

set stroke_width 1
set color $black

set x_start [expr { round( $x_midpoint * -1) } ]
set x_stop [expr { round( $x_midpoint) } ]
set x_prev $x_start
set y_prev [f_y $x_prev $k ]
for {set x $x_start} { $x < $x_stop } { incr x 100 } {
    set y [f_y $x $k ]
    # translate
    set x_prime [expr { $x + $x_midpoint } ]
    set y_prime [expr { $y } ]
    if { $y_prime > -1 && $y_prime < $y_max } {
        set path [mml_path_spec [list $x_prev $y_prev $x_prime $y_prime]]
        exec gm convert -stroke $color -strokewidth $stroke_width -draw "path '${path}'" $new_file $new_file
    } else {
        puts "skipped x_prime $x_prime y_prime $y_prime"
    }
    set x_prev $x_prime
    set y_prev $y_prime
}

#set item2 "circle 288,288 ${x_max_radius},${x_max_radius}"
#set item3 "path 'M 10 10 L 100 150 L 200 450'" 
#exec gm convert -fill $skyblue -draw $item2 $new_file $new_file
#gbar_corolla 6 $new_file
#gbar_leaf 200 $new_file
#exec gm convert $fill "#cccc33" $draw "circle 288,288 300,300" $new_file $new_file
# leaf
puts "done."
