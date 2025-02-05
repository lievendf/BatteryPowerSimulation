# Battery Power Simulation

## Overview

This tool allows to simulate the effect of adding one or more batteries to you home configuration.

It can process the [Fluvius](https://mijn.fluvius.be/verbruik/) quarter hour data from csv file and calculate:
- Simulated power consumption from net
- Simulated power injection to net
- Difference in power consumption (actual vs simulated)
- Difference in power injection (actual vs simulated)
- Consumption profit
- Injection loss
- Total annual saving
- Payback period

The calculations are based on the following configurable parameters:
- Battery capacity (kWh)
- Number of batteries
- Maximum charge/discharge power (kW)
- Battery purchase price (€)
- Consumption tarif (€/kWh)
- Injection tarif (€/kWh)
- Round trip efficiency (%)

Current default settings are in Settings.cls and are based on the [HomeWizard plug-in battery](https://www.homewizard.com/nl-be/plug-in-battery/) and the average rates of Belgian power provider [Ecopower](https://www.ecopower.be/) as of January 2025.

## Usage

This application uses Progress OpenEdge.
A ["Classroom edition"](https://www.progress.com/openedge/classroom-edition) can be download to compile and run.
PDSOE (Eclipse) and VSCode project configuration is provided.

Make sure to download the quarter hour data for a period of 1 year from the [Fluvius](https://mijn.fluvius.be/verbruik/) site and reference the file in Main.p.

Adjust Main.p and Settings.cls to your needs, no fancy UI is provided (yet) 🤓 

All feedback is welcome!
