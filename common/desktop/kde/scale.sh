#!/bin/bash

# Get all outputs
OUTPUTS=$(kscreen-doctor -o | grep 'Output' | awk '{print $3}')
SCALE_FACTOR=2

# Apply scaling to each output
for OUTPUT in $OUTPUTS; do
    echo "Applying scaling factor of $SCALE_FACTOR to output $OUTPUT"
    kscreen-doctor output.$OUTPUT.scale.$SCALE_FACTOR
done