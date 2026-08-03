# 🛠️ Construction AIO

> A RuneScape 3 Construction helper for **Construction Contracts**, **Furniture Construction**, and **Plank Making**.

![Status](https://img.shields.io/badge/status-beta-f4a62a?style=flat-square)
![Activities](https://img.shields.io/badge/activities-3-7b5428?style=flat-square)

---

## ✨ Included activities

| Activity | What it does |
| --- | --- |
| 📜 **Construction Contracts** | Reads a contract, travels to the target, opens supported doors, changes floors, chooses a build that has materials available, and hands in completed contracts. |
| 🪑 **Build Furniture** | Opens the Furniture workbench, finds the selected furniture, verifies materials, builds a batch, then banks or uses Furniture storage. |
| 🪵 **Make Planks** | Banks selected logs, uses a sawmill, and repeats until the inventory contains enough planks to bank again. |

---

## 📦 Installation

1. Extract/copy the `Construction_AIO` folder to:

   ```text
   %USERPROFILE%\MemoryError\Lua_Scripts\Construction_AIO
   ```

2. Run `Main.lua` through your MemoryError Lua environment.
3. Keep the script folder structure intact:

   ```text
   Construction_AIO/
   ├── Main.lua
   ├── Config.lua
   ├── ConstructionGUI.lua
   ├── Data/
   └── Modules/
   ```

> ⚠️ `Main.lua` expects this exact folder location. Do not rename the `Construction_AIO` folder unless you also update `SCRIPT_DIR` in `Main.lua`.

---

## 🎛️ Before pressing Start

1. Open the **Construction AIO** interface.
2. Select an activity from **Activity**.
3. Configure that activity's settings.
4. If your bank uses a PIN, enable **Use Bank PIN** and enter the four digits.
5. Press **Start**.

During a run, the general settings are intentionally hidden so that an active configuration cannot be changed accidentally. Use **Pause** to reveal them again; use **Resume** to continue or **Stop** to end the current activity.

> 🔐 The PIN is saved in the local Construction AIO config file. Do not share that file.

---

## 📜 Construction Contracts

### Preparation

- Carry an active **Construction contract**.
- Keep the **Inventory interface open** before starting.
- Have the **House Teleport** ability available on action bar.
- Set house teleport to oudsite portal.
- Make sure tat it teleports you to Rimmington
- Make sure your bank/preset contains the materials required for your contract builds.
- A **Plank box is optional**. Without one, the script counts planks in the inventory only.

### What happens

**Quick flow:** Read contract → travel to the target town → enter the building → find and repair hotspots → check whether the contract is complete. If materials are missing, return Home/Rimmington, load the preset, then continue the same contract.

### Contract loop explained

1. **Read contract** — The script opens the Construction contract in your inventory and reads the target town, NPC, and number of repairs still required.
2. **Travel to town** — It uses the appropriate lodestone when the player is outside the target town. When enabled, Surge/Dive may be used only to speed up a longer route.
3. **Enter the building** — The script walks to the configured entrance, checks the front door, and opens it when necessary. Inside, it also handles known internal doors before a repair or before using stairs, so a closed door cannot block the route to another floor.
4. **Find a repair hotspot** — It searches the current floor for the nearest valid `... space` repair object and interacts with it.
5. **Choose a build** — Once the Build Furniture interface is open, every available build option is read. The script selects the best option for which every required material is available.
6. **Missing materials** — If no build option is possible, the script uses House Teleport to return to Home/Rimmington. It loads the last bank preset, fills a carried Plank box when applicable, and checks the materials again before travelling back.
7. **Repeat repairs** — After each completed repair, the script looks for the next repair on the same floor. If none is found, it checks internal doors first and then changes floor when needed.
8. **Finish the contract** — Once all repairs are complete, the script returns Home/Rimmington, speaks to the Estate agent, requests a new contract, prepares the preset, and starts the next contract loop.

### Material checks

For every build option, the script reads and logs **all** required materials. This includes:

- Planks (inventory + Plank box when carried)
- Any nail type
- Bolt of cloth, candles, bars, and other standard inventory materials

If no option can be built, the script goes to **Rimmington usging house teleport** first, loads the last preset, optionally refills the Plank box, and verifies the materials again. It stops with a clear message if the preset is still insufficient.

### Supported navigation

The contract module includes data for supported towns, entrances, front doors, internal doors, stairs, ladders, and known room routes. It can also use travel abilities when the distance is worthwhile. The **Use Surge / Dive while travelling** toggle lets you disable these abilities completely if you prefer normal walking. Do not move the player manually while it is travelling or repairing.

---

## 🪑 Build Furniture

Stand near a supported **Furniture workbench**, bank, and (optionally) Furniture storage before starting. Furniture mode does not travel to a training location for you.
Start in Rimmington near The **Furniture workbench**, bank, and (optionally) Furniture storage before starting. Furniture mode does not travel to a training location for you.

### Choose what to build

There are two ways to select furniture:

#### 1. Preset choice

Choose a **Plank type** and a **Furniture type**. The script creates the exact combined name.

| Plank type | Furniture type |
| --- | --- |
| Wooden, Oak, Teak, Mahogany, Eternal | Chair, Bench, Round table, Long table |

Example: **Teak** + **Round table** builds **Teak round table**.

The preset recipes have a full material check before opening the workbench and again after banking.

#### 2. Free furniture choice

Enable **Free furniture choice** and enter the exact in-game furniture name, for example:

```text
Eternal long table
```

The script searches the Furniture Construction interface, selects its single matching result, and uses the interface material checkmarks. Use an exact name that produces one result.

### Furniture loop

**Quick flow:** Open workbench → search or reuse the selected furniture → verify materials → build → optionally store completed items → bank → refill Plank box when carried → load preset → repeat.

### Furniture storage

Enable **Store built items in Furniture storage** to deposit the completed furniture before banking. The script waits for storage to open, stores with Space, closes it, and then continues to the bank cycle.

### Banking behaviour

- The Plank box is filled **before** loading the last preset, so inventory planks can be moved into the box first.
- Without a Plank box, the script simply loads the preset.
- For preset furniture, materials are checked after banking. The script stops after two unsuccessful bank attempts instead of repeatedly trying to build with insufficient materials.

---

## 🪵 Make Planks

1. Select the desired **Plank Type**.
2. Optionally enable **Load last preset**.
3. Start while positioned where the script can interact with the bank and sawmill.

The module keeps at least 15 selected logs before going to the sawmill. Once the inventory is full or contains 15 or more selected planks, it returns to the bank.

If **Load last preset** fails, the module switches to manual banking: it deposits the inventory, withdraws selected logs, and continues.

---

## ⏸️ Controls

| Button | Behaviour |
| --- | --- |
| ▶️ **Start** | Starts the selected activity. |
| ⏸️ **Pause** | Pauses the current module safely. |
| ▶️ **Resume** | Continues the paused module. Furniture rechecks its selected build/materials. |
| ⏹️ **Stop** | Stops the active module and returns the GUI to its editable state. |
| 🚪 **Exit** | Closes the complete script. |

The separate MemoryError **Logs** and **Tracked Skills** overlays are enabled by `Main.lua`.

---

## 🧭 Troubleshooting

| Log message / symptom | What to check |
| --- | --- |
| `Inventory is not open` | Open the in-game Inventory interface, then start again. |
| `Preset contains insufficient materials` | Update your last bank preset with the required planks and other materials. The log lists each required item. |
| `No plank box found` | This is a warning, not an error. Planks will be counted from the inventory only. |
| `Bank could not be opened` | Make sure the player reached Home and can interact with the bank chest. |
| `Furniture interface did not open` | Stand within reach of the Furniture workbench and make sure the player is not already moving/processing another action. |
| `Furniture storage interface 1518 did not open` | Move close to Furniture storage, or disable the storage option. |
| `Build interface did not open` | The repair hotspot may be blocked or not reachable. Do not move the player manually; share the complete log for that contract. |

---

## 🧪 Reporting a bug

When reporting an issue, include:

1. The selected activity and its GUI settings.
2. A screenshot of the player/interface if relevant.
3. The complete log from **Start pressed** until the first error or unexpected action.
4. The current inventory when the issue is material or banking related.

That makes it possible to fix the first real failure instead of a later side effect.

---

## ⚠️ Beta notice

This project is still in beta. Supported Contract navigation is data-driven and new buildings, doors, routes, or interface changes may need to be added over time. Test changes carefully and keep a backup of your working script folder.
