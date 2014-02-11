# file: data-analyzer.tcl

source mad-lab-lib.tcl

# ..............................................................
#  input global temperature data
source convert-gt.tcl

set t_fi_list [list \
                   www-users.york.ac.uk-tildekdc3-papers-coverage2013-had4_krig_std.temp.txt \
                   www-users.york.ac.uk-tildekdc3-papers-coverage2013-had4_hybrid_std.temp.txt]
#  data files from www-users.york.ac.uk/~kdc3/papers/coverage2013/
#  had4_hybrid_st.temp and had4_krig_std.temp formats are identical and tab delimited:
#  Year_decimal global_temperature_oC Error_range
#  example: 1979.04166667	-0.293750393543	0.0440333616436
#  The decimal portions of years are in increments of 1/12 starting with 1/24.
#  For example, "March 1980" is "1980 + 1/24 + 2 x 1/12 = 5/24" or 1980.208333
#  
#  Global temperatures are gt in Celsius/Centigrade/Kelvin from a statistically normalized reference point
set cfcount 0
foreach filename $t_fi_list {
    puts "cfcount $cfcount"
    set globalT_fi($cfcount) [lrange [import_climate_datafile $filename] 1 end]
    # list in form:  year_decimal gt gt_err year month
    # ignore first row, it consists of titles
    #  Data in this format:
    #  year_decimal = YYYY + (MM-1)/12 + 1/24, where YYYY-MM is year and month
    #  gt      = offset of temperature in Celsius from a consistent reference temperature.
    #  error_amt     = measurement error.
    list_of_lists_to_file gt-data-${cfcount}.txt $globalT_fi($cfcount)
    incr cfcount
}

# ..............................................................
# input earthquake data
source convert-eq.tcl

set eq_fi_list [list "IEB-export-earthquakes-as-an-HTML-table.html"]
# efcount = earthquake file counter
set efcount 0
foreach filename $eq_fi_list {
    puts "efcount $efcount"
    set eq_fi($efcount) [lrange [import_earthquake_datafile $filename] 1 end]
    # ignore first row, it consists of titles
    # list: mag depth day time_utc lat lon region event_id timestamp_epoch energy_exajoules year month year_decimal energy_error_min energy_error_max energy_error
    list_of_lists_to_file eq-data-${efcount}.txt $eq_fi($efcount)
    incr efcount
}

# ..............................................................
# Loop through the various permutations of earthquake data and climate data separately.
# Each analysis only uses one earthquake and one climate data set.
set ct_list [array names globalT_fi]
set eq_list [array names eq_fi]
# cfc = climate file counter
foreach cfc $ct_list {
    puts "cfc $cfc"
    #  Sort data chronologically so that changes per unit time can be tracked. 
    # Remove the first row (of titles)
    #  Sort table_list by year_dec_input. There should only be one per interval.
    set gt_data_lists [lsort -index 0 -real -increasing [lrange $globalT_fi($cfc) 1 end]]

    # efc = earthquake file counter
    foreach efc $eq_list {
    puts "efc $efc"
        set eq_data_lists [lrange $eq_fi($efc) 1 end]
        # Aggregate earthquake data to climate data intervals
        # First, set eq_yyyy_mm_energy(for all ct_year_decimal cases) to
        # the low value of an earthquake just under the measurement threashold limit.
        set cpc 0
        array unset eqe_yyyy_mm_arr
        array unset eqe_yyyy_mm_err_arr
        array unset gt_year_dec_arr
        foreach gt_row_list $gt_data_lists {
            incr cpc
            set year_dec_input [lindex $gt_row_list 0]
            set gt [lindex $gt_row_list 1]
            set error_amt [lindex $gt_row_list 2]
            set year [lindex $gt_row_list 3]
            set month [lindex $gt_row_list 4]
            set yyyymm $year
            # append a zero if length of $month < 2
            if { [string length $month ] < 2 } {
            append yyyymm "0"
            }
            append yyyymm $month
            # Low limit is 6.5 mag. 6.4 is low error limit, so magnitude 6.3 is the low threashold
            # energy of 6.4 mag eq = k, where energy = \[expr { pow( 10. , 1.5 * $mag + 16.1) * $eq_unit_conv_factor } \]
            # k = 5.011872336272756 @ mag = 6.4
            # k = 3.548133892335761 @ mag = 6.3
            # Using magnitude 6.3, because 6.4 is error range for 6.5 earthquakes (a data boundary value)
            # This should be re-worked to some kind of background earthquake energy average..
            set eqe_below_threshold 3.548133892335761
            set eqe_yyyy_mm_arr($yyyymm) $eqe_below_threshold
            set eqe_yyyy_mm_err_arr($yyyymm) 0.0
            set eqe_yyyy_mm_min_arr($yyyymm) 0.0
            set eqe_yyyy_mm_max_arr($yyyymm) 0.0

        }

        # ..............................................................
        # Calculations
        
        foreach eq_row_list $eq_data_lists {
            # list: mag depth day time_utc lat lon region event_id timestamp_epoch energy_exajoules year month year_decimal energy_error_min energy_error_max energy_error
            set year [lindex $eq_row_list 10]
            set month [lindex $eq_row_list 11]
            set eqe [lindex $eq_row_list 9]
            set eq_error_min [lindex $eq_row_list 13]
            set eq_error_max [lindex $eq_row_list 14]
            set eq_error [lindex $eq_row_list 15]
            set yyyymm $year
            if { [string length $month] < 2 } {
                append yyyymm "0"
            }
            append yyyymm $month
            # only accumulate if there is coorespondence to a global temperature interval
            if { [info exists eqe_yyyy_mm_arr($yyyymm) ] } {
                if { $eqe_yyyy_mm_arr($yyyymm) <= $eqe_below_threshold } {
                    # clear out any threshold value before accumulating data points at interval
                    set eqe_yyyy_mm_arr($yyyymm) $eqe
                } else {
                    set eqe_yyyy_mm_arr($yyyymm) [expr { $eqe_yyyy_mm_arr($yyyymm) + $eqe } ]
                }
                set eqe_yyyy_mm_err_arr($yyyymm) [expr { $eqe_yyyy_mm_err_arr($yyyymm) + $eq_error } ]
                set eqe_yyyy_mm_min_arr($yyyymm) [expr { $eqe_yyyy_mm_min_arr($yyyymm) + $eq_error_min } ]
                set eqe_yyyy_mm_max_arr($yyyymm) [expr { $eqe_yyyy_mm_max_arr($yyyymm) + $eq_error_max } ]
                # set reverse pointing references? No. building list of refferences from array indexes directly
                #set eqe_year_arr($yyyymm) $year
                #set eqe_month_arr($yyyymm) $month
            } else {
                #puts "ref131. No global temp data for $yyyymm"
            } 
        }
        # convert eqe_yyyy_mm*_arr to list of lists and fold into climate table
        set arr_names_list [lsort -integer [array names eqe_yyyy_mm_arr]]
        # arr_names_list should be identical year and month references from gt_data_lists
        if { [llength $arr_names_list] ne [llength $gt_data_lists] } {
            set error_txt "error(ref127): arr_names_list differs in length from gt_data_lists"
            error $error_txt
        }
        set gt2_data_lists [list ]
        set titles_list [list year_decimal gt gt_err year month eqe eqe_err eqe_min eqe_max]
        lappend gt2_data_lists $titles_list
        set gt_row_count 0
        foreach gt_row_list $gt_data_lists {
            set gteq_row_list $gt_row_list
            # list in form:  year_decimal gt gt_err year month
            set year [lindex $gteq_row_list 3]
            set month [lindex $gteq_row_list 4]
            set yyyymm $year
            if { [string length $month] < 2 } {
                append yyyymm "0"
            }
            append yyyymm $month
            lappend gteq_row_list $eqe_yyyy_mm_arr($yyyymm) $eqe_yyyy_mm_err_arr($yyyymm) $eqe_yyyy_mm_min_arr($yyyymm) $eqe_yyyy_mm_max_arr($yyyymm) 
            lappend gt2_data_lists $gteq_row_list
        }
        # save gT data with eq accumulations
        list_of_lists_to_file gt-eq-combo.txt $gt2_data_lists

        # remove title row and replace gt_ with gt2_ data
        # set titles_list [lindex $gt2_row_lists 0]
        # redundant, ie \[list year_decimal gt gt_err year month eqe eqe_err eqe_min eqe_max \]
        set gt_data_lists [lrange $gt2_data_lists 1 end]

        # ..............................................................
        # statistics calculations for analysis etc

        # Graphing procedues will gather their stats for automatically maximizing
        # use of graphing region.

        
        # set initial max and min conditions to first row values.
        set row_list [lindex $gt_data_lists 0]
        set i 0
#        foreach title $titles_list {
#            set $title \[lindex $row_list $i\]
#        }
        set year_decimal [lindex $row_list 0]

        set gt [lindex $row_list 1]
        set gt_err [lindex $row_list 2]
        set year [lindex $row_list 3]
        set month [lindex $row_list 4]
        # eqe refers to earthquake energy for the period (month)
        set eqe [lindex $row_list 5]
        set eqe_err [lindex $row_list 6]
        set eqe_min [lindex $row_list 7]
        set eqe_max [lindex $row_list 8]
        set eqe_tot $eqe
        set gt_max [expr { $gt + $gt_err } ]
        set gt_min [expr { $gt - $gt_err } ]
        # gt_tot isn't useful.
        set eqe_diff 0.
        set eqe_diff_max 0.
        set eqe_diff_min 0.
        set gt_diff 0.
        set gt_diff_max 0.
        set gt_diff_min 0.
        #  check gt_diff_tot against the last gt.
        set gt_diff_tot 0.

        # Compute contiguous temperature trends, delta t and delta eqe
        # Build trend_lists 
        set trend_lists [list ]
        set trend_titles_list [list gt_interval_count gtdt gtdt_err eqe_tot eqe_min_tot eqe_max_tot eqedt eqedt_min eqedt_max]
        lappend trend_lists $trend_titles_list
        foreach row_list $gt_data_lists {

            set gt_prev $gt
            set eqe_prev $eqe

            set gt [lindex $row_list 1]
            set eqe [lindex $row_list 5]

            set eqe_diff  [expr { $eqe - $eqe_prev } ]
            set gt_diff [expr { $gt - $gt_prev } ]

            # Adjust maximum or minimum values?
            if { $eqe > $eqe_max } {
                # new eqe_max
                set eqe_max $eqe
            } elseif { $eqe < $eqe_min } {
                # new eqe_min
                set eqe_min $eqe
            }
            if { $gt > $gt_max } {
                # new gt_max
                set gt_max $gt
            } elseif { $gt < $gt_min } {
                # new gt_min
                set gt_min $gt
            }

            # Adjust maximum or minimum diff values?
            if { $eqe_diff > $eqe_diff_max } {
                # new eqe_diff_max
                set eqe_diff_max $eqe_diff
            } elseif { $eqe_diff < $eqe_diff_min } {
                # new eqe_diff_min
                set eqe_diff_min $eqe_diff
            }
            if { $gt_diff > $gt_diff_max } {
                # new gt_diff_max
                set gt_diff_max $gt_diff
            } elseif { $gt_diff < $gt_diff_min } {
                # new gt_diff_min
                set gt_diff_min $gt_diff
            }

            # accumulate energy
            set eqe_tot [expr { $eqe_tot + $eqe } ]
            
        }
        puts "Min energy (ExaJoules): $eqe_min"
        puts "Max energy (ExaJoules): $eqe_max"
        puts "Total energy (ExaJoules): $eqe_tot"
        set y_eq_range [expr { $eqe_max - $eqe_min } ]
        puts "Energy range: $y_eq_range"
        set y_eq_diff_range [expr { $eqe_diff_max - $eqe_diff_min } ]

        puts "Min temperature (C): $gt_min"
        puts "Max temperature (C): $gt_max"
        set y_ct_range [expr { $gt_max - $gt_min } ]
        puts "Temperature range: $y_ct_range"
        set y_ct_diff_range [expr { $gt_diff_max - $gt_diff_min } ]


        # Split data into climate temperature trends (down or up) curves
        # dcounter = slope or trend change counter
        # get first row to set initial variables
        set row_list [lindex $gt_data_lists 0]
        # row_list \[list year_decimal gt gt_err year month eqe eqe_err eqe_min eqe_max \]
        set year_decimal [lindex $row_list 0]
        set gt [lindex $row_list 1]
        set gt_err [lindex $row_list 2]
        set year [lindex $row_list 3]
        set month [lindex $row_list 4]
        # eqe refers to earthquake energy for the period (month)
        set eqe [lindex $row_list 5]
        set eqe_err [lindex $row_list 6]
        set eqe_min [lindex $row_list 7]
        set eqe_max [lindex $row_list 8]

        set dcounter 1
        set gt_dy_arr($dcounter) 0.
        set eqe_yyyy_mm_dy_arr($dcounter) 0.
        set ct_months_dy_arr($dcounter) 0

        set gt_tot 0.
        set eqe_tot 0.
        set gt_interval_count 0
        set eqe_min_tot 0.
        set eqe_max_tot 0.

        set gt_prev $gt
        set delta_t_prev 0
        set eqe_tot_prev $eqe_tot
        set gt_tot_prev $gt_tot
        set eqe_max_tot_prev $eqe_max_tot
        set eqe_min_tot_prev $eqe_min_tot
        foreach row_list $gt_data_lists {
            set year_decimal [lindex $row_list 0]
            set gt [lindex $row_list 1]
            set gt_err [lindex $row_list 2]
            set year [lindex $row_list 3]
            set month [lindex $row_list 4]
            # eqe refers to earthquake energy for the period (month)
            set eqe [lindex $row_list 5]
            set eqe_err [lindex $row_list 6]
            set eqe_min [lindex $row_list 7]
            set eqe_max [lindex $row_list 8]

            set delta_t [expr { $gt - $gt_prev } ]
            set delta_factor [expr {  $delta_t * $delta_t_prev } ]
            if { $delta_factor < 0. } {
                # prior trend is now defined, values are fixed
                set eqedt [expr { $eqe_tot_prev - $eqe_tot } ]

                # min trend, chooses eqe values that minimize trend
                # Since all eqe values are greater than 0, 
                # eqe_min_tot_prev - eqe_max_tot will always give the largest change
                set eqedt_min [expr { $eqe_min_tot_prev - $eqe_max_tot } ]
                # eqe_max_tot_prev - eqe_min_tot will always give the smallest change                
                set eqedt_max [expr { $eqe_max_tot_prev - $eqe_min_tot } ]

                # create a trend row
                # add it to trend_lists
                #set trend_titles_list \[list gt_interval_count gtdt gtdt_err eqe_tot eqe_min_tot eqe_max_tot eqedt eqedt_min eqedt_max\]
                set trend_row_list [list $gt_interval_count $gt_tot $gt_err $eqe_tot $eqe_min_tot $eqe_max_tot $eqedt $eqedt_min $eqedt_max]
                lappend trend_lists $trend_row_list 
                set eqe_tot_prev $eqe_tot
                set gt_tot_prev $gt_tot
                set eqe_max_tot_prev $eqe_max_tot
                set eqe_min_tot_prev $eqe_min_tot
                # create start point of new trend
                set gt_tot 0.
                set eqe_tot 0.
                set eqe_min_tot 0.
                set eqe_max_tot 0.
                set gt_interval_count 0
            }
            # Assume this point is the last in the trend (until next point is examined).
            # set (accumulated) trend values. 
            set gt_tot [expr { $gt_tot + $gt } ]
            set eqe_tot [expr { $eqe_tot + $eqe } ]
            set eqe_min_tot [expr { $eqe_min_tot + $eqe_min } ]
            set eqe_max_tot [expr { $eqe_max_tot + $eqe_max } ]
            incr gt_interval_count

            set delta_t_prev $delta_t
            set gt_prev $gt
        }
        # end of row_list loop
        # prior trend is now defined, values are fixed
        set eqedt [expr { $eqe_tot_prev - $eqe_tot } ]
        
        # min trend, chooses eqe values that minimize trend
        # Since all eqe values are greater than 0, 
        # eqe_min_tot_prev - eqe_max_tot will always give the largest change
        set eqedt_min [expr { $eqe_min_tot_prev - $eqe_max_tot } ]
        # eqe_max_tot_prev - eqe_min_tot will always give the smallest change                
        set eqedt_max [expr { $eqe_max_tot_prev - $eqe_min_tot } ]
        
        # create a trend row
        # add it to trend_lists
        #set trend_titles_list \[list gt_interval_count gtdt gtdt_err eqe_tot eqe_min_tot eqe_max_tot eqedt eqedt_min eqedt_max\]
        set trend_row_list [list $gt_interval_count $gt_tot $gt_err $eqe_tot $eqe_min_tot $eqe_max_tot $eqedt $eqedt_min $eqedt_max]
        lappend trend_lists $trend_row_list 

        list_of_lists_to_file gt-eq-trends.txt $trend_lists
        # g2_data_lists: year_decimal gt gt_err year month eqe eqe_err eqe_min eqe_max
        graph_lol lin-lin gt-eq_plot-$cfc-$efc.png "" gt2_data_lists [list 0 1] [list 4 6 7] "origin" "" 12 12 "Global T (C)" "Earthquake e (J)" 
# graph_lol {type "lin-lin"} filename region data_list_of_lists x_index y_index x_style y_style x_ticks_count y_ticks_count x_title y_title
        graph_lol lin-lin dgt-eq-plot-$cfc-$efc.png "" trend_lists [list 1 2] [list 3 4 5] "origin" "origin" 12 12 "Global T change (C)" "Earthquake e (J)"
        graph_lol lin-lin dgt-deq-plot-$cfc-$efc.png "" trend_lists [list 1 2] [list 6 7 8] "origin" "origin" 12 12 "Global T change (C)" "Earthquake e change (J)"
    }
}
