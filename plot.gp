# plot.gp
# output to png with decend font and image size
set terminal png font "Arial,10" size 700,500
set output "progress.png"

set title "Elixir Epoxi processing progress over time"
set xlabel "Time (ms)"
set ylabel "Emails Sent"
set key top left # put labels in top-left corner

# limit x range to 15.000 ms instead of dynamic one, must-have
# when generating few graphs that will be later compared visually
set xrange [0:15000]

# plot series (see below for explanation)
# plot [file] with [line type] ls [line style id] [title ...  | notitle]

plot  "progress-decode.log"    with steps   ls 1 title "Decode",\
      "progress-send.log"      with lines   ls 3 title "Send",
