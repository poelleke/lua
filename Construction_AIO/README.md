# Construction AIO

> A RuneScape 3 Construction helper for Construction Contracts, Furniture Construction, Fort Forinthry Construction, and Construction Materials.

## Included activities

| Activity | Purpose |
| --- | --- |
| **Construction Contracts** | Completes supported Construction Contracts, including travel, doors, stairs, material checks, banking, and new contracts. |
| **Build Furniture** | Builds a selected Furniture Construction item in Rimmington, optionally storing the finished items before banking. |
| **Fort Forinthry Construction** | Builds or resumes a selected Fort building tier, using Optimal Construction hotspots when available. |
| **Construction Materials** | Makes planks, refined planks, frames, and stone wall segments. |

## Installation

1. Copy the complete `Construction_AIO` folder to:

   ```text
   %USERPROFILE%\MemoryError\Lua_Scripts\Construction_AIO
   ```

2. Keep the folder structure intact:

   ```text
   Construction_AIO/
   ├── Main.lua
   ├── Config.lua
   ├── ConstructionGUI.lua
   ├── Data/
   |     ├── Data.lua
   |     └── Functions.lua
   └── Modules/
         ├── Contracts.lua
         ├── Furniture.lua
         ├── FortConstruction
         └── ConstructionMaterials.lua
   ```

3. Start `Main.lua` in MemoryError.

`Main.lua` expects this folder structure. If you rename or move the project, update `SCRIPT_DIR` in `Main.lua` too.

## Before starting

1. Select an activity in the Construction AIO window.
2. Configure the settings for that activity.
3. If needed, enable **Use Bank PIN** and enter the correct PIN.
4. Press **Start**.

While an activity is running, the general settings are hidden to avoid accidental changes. Press **Pause** to reveal and edit them, then **Resume** to continue.

The Bank PIN is saved in the local config file. Do not share that file.

## Construction Contracts

### Preparation

- Carry an active **Construction contract**.
- Keep the in-game Inventory interface open.
- Have **House Teleport** available on the action bar and configured to Home/Rimmington.
- Make sure the last bank preset contains the materials needed for the contract builds.
- A **Plank box** is optional. Without one, planks are counted from the inventory only.

### Contract loop

1. Reads the contract and its destination.
2. Travels to the correct town with lodestones when needed.
3. Walks to the configured building entrance, checks the front door, and enters the building.
4. Handles known internal doors, ladders, and stairs.
5. Finds the nearest repair hotspot on the current floor.
6. Reads every available build option and its full material list.
7. Selects a build only when all required materials are available.
8. Repeats repairs until the contract is complete.
9. Returns Home, hands in the contract, requests a new one, prepares materials, and starts again.

### Material checks

The build-interface parser checks every listed material, including:

- Planks, counted in inventory and Plank box when carried
- Nails
- Bolt of cloth
- Candles
- Bars
- Other inventory materials displayed by the build option

If no option can be built, the script returns Home, loads the last preset, refills the Plank box when carried, and checks the selected build again. It stops with a clear log when the preset remains insufficient.

### Travel abilities

The **Use Surge / Dive while travelling** setting can speed up longer outdoor routes. Disable it if you prefer normal walking only. The script avoids abilities for short routes and must still handle the configured entrance and doors normally.

## Build Furniture

Start near the Furniture workbench and bank in Rimmington. The activity does not travel to Rimmington automatically.

### Selecting furniture

There are two selection modes.

#### Preset choice

Choose a plank type and furniture type. The script combines them into the exact furniture name.

| Plank type | Furniture type |
| --- | --- |
| Wooden, Oak, Teak, Mahogany, Eternal | Chair, Bench, Round table, Long table |

Example: **Teak** + **Round table** selects **Teak round table**.

#### Free furniture choice

Enable **Free furniture choice** and enter the exact in-game name, for example:

```text
Eternal long table
```

Use a name that returns one result in the Furniture Construction search.

### Furniture loop

1. Opens the Furniture workbench.
2. Reuses the already selected furniture when it matches the GUI selection; otherwise clears, searches, and selects it.
3. Checks the visible material status before building.
4. Starts construction with Space and waits for the batch to finish.
5. If enabled, uses the direct **Furniture storage** action to store the completed items. It waits for the player to walk to storage and finish the action before banking.
6. Fills a Plank box first when carried, then loads the last preset.
7. Repeats the selected furniture.

For preset furniture, materials are checked before opening the workbench and again after banking. The script stops after two unsuccessful material-bank attempts.

## Construction Materials

Use this activity to create construction inputs. The module handles banking, selected-material withdrawal, station interaction, and repeated processing.

| Mode | Station | Location |
| --- | --- | --- |
| Planks | Sawmill | Home/Rimmington or Fort Forinthry |
| Refined planks | Fort sawmill | Fort Forinthry |
| Frames | Woodworking bench | Fort Forinthry |
| Stone wall segments | Stonecutter | Fort Forinthry |

When making normal planks, the script detects whether it was started in Home or Fort Forinthry and selects the correct sawmill automatically. Starting the wrong material mode outside its supported area stops safely with a clear message.

If **Load last preset** does not provide the selected input material, Construction Materials switches to manual banking for that run.

## Fort Forinthry Construction

Choose a building and tier in the GUI. Supported building choices are:

- Workshop
- Town Hall
- Chapel
- Command Centre
- Kitchen
- Guardhouse
- Grove Cabin
- Ranger's Workroom
- Botanist's Workbench
- Eternal reinforcement

### Normal Fort build flow

1. The script first looks for an existing Fort Construction hotspot within the Fort.
2. If one exists, it identifies the building area from the hotspot and resumes that build before selecting a new blueprint.
3. If no build is active, it checks the selected tier's required frames and Stone wall segments.
4. Missing final materials are withdrawn through normal Fort bank actions. Fort Construction never uses **Load last preset**.
5. The script opens the Fort Forinthry blueprints table, selects the configured blueprint, and confirms it.
6. It walks to the building area and prioritises an **Optimal Construction hotspot**.
7. When no optimal hotspot is available, it falls back to a normal **Construction hotspot**.
8. After each action it scans again, follows a moved optimal hotspot, and continues until the active build is complete.
9. It returns to the Fort bank and begins the next selected build cycle.

The Grove Cabin route includes Side gate handling so the script can return to the main Fort service side for banking and production.

### Build from scratch

Enable **Build from scratch** when you want the script to create missing Fort construction materials itself.

The script checks the bank from the final item backwards:

```text
Required frames
  -> missing refined planks for those frames
  -> missing planks for those refined planks
  -> missing logs for those planks

Required Stone wall segments
  -> missing Limestone for those segments
```

It keeps usable materials already in the bank. For example, existing frames reduce the number of refined planks, planks, and logs that need to be made.

Production order:

1. Make missing planks at the Fort sawmill.
2. Make missing refined planks at the Fort sawmill.
3. Make missing frames at the Woodworking bench.
4. Cut missing Stone wall segments at the Stonecutter.
5. Deposit the batch, recalculate every shortage, then repeat until the final construction materials are ready.
6. Withdraw the exact final frame and Stone wall segment amounts, then continue with the normal blueprint and hotspot flow.

The log prints the complete plan, including required, already stored, and missing counts for logs, planks, refined planks, frames, Limestone, and Stone wall segments. If the bank does not contain enough base logs or Limestone, the script stops before wasting an action.

## Controls

| Button | Behaviour |
| --- | --- |
| **Start** | Starts the selected activity. |
| **Pause** | Safely pauses the active module and reveals general settings. |
| **Resume** | Continues the paused module. Furniture rechecks the selected furniture and materials. |
| **Stop** | Stops the active module and returns the GUI to editable state. |
| **Exit** | Closes Construction AIO. |

MemoryError's separate **Logs** and **Tracked Skills** overlays are enabled by `Main.lua`.

