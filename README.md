# Instructions
1. Copy the (measure_performance.lua)[measure_performance.lua] to Saved Games\DCS\Scripts
2. Edit/Create Export.lua file with following line, placed ideally at start

```lua
local measure_performance=require('lfs');dofile(measure_performance.writedir()..'Scripts/measure_performance.lua')
```
3. Start DCS
4. Create mission and give it name inside Mission editor
5. Place aircraft, set them as Clients, and name the group (name of group will be used to create csv file ++Saved Games\DCS\Telemetry\mission_name\group_name.csv++
7. Run mission
8. Spawn into aircraft and Fly
9. Exit mission
10. The csv file contains telemetry
