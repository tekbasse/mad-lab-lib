source mad-lab-lib/mad-lab-lib.tcl



proc fx_rtheta { radius theta } {
    set x [expr { round( $radius * cos( $theta ) ) } ]
}

proc fy_rtheta { radius theta } {
    set y [expr { round( $radius * sin( $theta ) ) } ]
}



set x_max_inches [expr { 1 * 12 } ]
set y_max_inches [expr { 5 * 12 } ]
set x_min 0
set y_min 0


# Ellipse with focal point at c,
# given x^2/a^2 + y^2/b^2 = 1
# y = sqrt(pow($a,2) - pow($x,2))*$b/$a

# For practical purposes, we want a curve to work with the focal point
# c being some predetermined distance from the vertice point a.
# That is, a - c = local_focal_distance
# And we are looking for a range of 2*c.
# set to depth of antenna:
set local_focal_distance [expr { $x_max_inches * 1. } ]
set range_inches [expr { 12. * 1000. } ]
set c [expr { $range_inches / 2.} ]
set a [expr { $c + $local_focal_distance } ]
set b [expr { sqrt( pow($a,2.) - pow($c,2.) ) } ]
puts "a $a"
puts "c $c"
puts "b $b"
# So up to this point x-axis is the focal distance.


set minuend_y [expr { pow($b,2.) } ]
set a_over_b_factor [expr { $a / $b } ]
proc f_y { x minuend a_over_b_factor } {
    puts " x $x minuend $minuend a_over_b_factor $a_over_b_factor"
    set y [expr { sqrt( ${minuend} - pow($x,2.) ) * $a_over_b_factor } ]
    return $y
}


set minuend_x [expr { pow($a,2.) } ]
set b_over_a_factor [expr { $b / $a } ]
proc f_x { y minuend b_over_a_factor } {
#    puts " y $y minuend $minuend b_over_a_factor $b_over_a_factor"
    set x [expr { sqrt( ${minuend} - pow($y,2.) ) * $b_over_a_factor } ]
    return $x
}



set x_max [expr { $x_max_inches * 72. } ]
set y_max [expr { $y_max_inches * 72. } ]
set x_midpoint [expr { $x_max / 2. } ]
set y_midpoint [expr { $y_max / 2. } ]
puts "x_max $x_max"
puts "y_max $y_max"

set x_origin [expr { $a - $c } ]
#set y_origin [expr { ( 0 ) } ]

set new_file "ellipse-${x_max}x${y_max}.png"
mml_new_filename $new_file $x_max $y_max

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

# radius is primarily determined by reflective material properties
set radius [expr { round( $y_max_inches * sin( 18. * $pi / 180.) * 10 ) / 20. }]
puts "$radius inches of focal point."



# alpha is angle between x-axis and page normal to view.
#set alpha $quartpi
#set sin_alpha [expr { sin( $alpha ) } ]
#set cos_alpha [expr { cos( $alpha ) } ]

set stroke_width 1
set color $black

set step [expr { 1. / 72. } ]
for {set i -1} { $i< 2} {incr i 2} {
    set color [lindex [list $black $skyblue $red] $i+1 ]
    set x_start [expr { $a * -1. } ]
    set x_stop [expr { $c * -1. } ]
    set x_prev [expr { int( $a ) } ]
    set y_prev [f_x $x_prev $minuend_x $b_over_a_factor ]
    set x_prev [expr { $x_prev * 72. } ]


    for {set x $x_start} { $x < $x_stop } {set x [expr { $x + $step} ] } {
        
        set y [f_x $x $minuend_x $b_over_a_factor ]
        # translate
        # plot units are in pixels, 72px/inch
        # approx 225 px / inch or 72 pt, or 28px per 9pt
        # so multiply each by 72
        set y_prime [expr { $y * 72 * $i + $y_midpoint  } ]
        set x_prime [expr { ( $a + $x ) * 72. } ]
        if { $y_prime > -1 && $y_prime < $y_max && $x_prime > -1 && $x_prime < $x_max } {
            set path [mml_path_spec [list $x_prev $y_prev $x_prime $y_prime]]
            exec gm convert -stroke $color -strokewidth $stroke_width -draw "path '${path}'" $new_file $new_file
        } else {
            puts "skipped x_prime $x_prime y_prime $y_prime"
        }
        
        set x_prev $x_prime
        set y_prev $y_prime
        
    }

}
