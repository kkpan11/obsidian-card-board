module SettingsState exposing
    ( SettingsState(..)
    , addBoardRequested
    , addColumnRequested
    , boardConfigs
    , cancelCurrentState
    , confirmAddBoard
    , confirmAddColumn
    , confirmDelete
    , deleteBoardRequested
    , deleteColumnRequested
    , editBoardAt
    , editGlobalSettings
    , init
    , mapBoardBeingAdded
    , mapBoardBeingEdited
    , mapColumnBeingAdded
    , mapGlobalSettings
    , moveBoard
    , moveColumn
    , settings
    )

import BoardConfig exposing (BoardConfig)
import Columns exposing (Columns, OptionsForSelect)
import DefaultColumnNames exposing (DefaultColumnNames)
import DragAndDrop.BeaconPosition exposing (BeaconPosition)
import GlobalSettings exposing (GlobalSettings)
import List.Extra as LE
import NewBoardConfig exposing (NewBoardConfig)
import NewColumnConfig exposing (NewColumnConfig)
import SafeZipper exposing (SafeZipper)
import Settings exposing (Settings)



-- TYPES


type SettingsState
    = AddingBoard NewBoardConfig Settings
    | AddingColumn NewColumnConfig Settings
    | ClosingPlugin Settings
    | ClosingSettings Settings
    | DeletingBoard Settings
    | DeletingColumn Int Settings
    | EditingBoard Settings
    | EditingGlobalSettings Settings



-- CREATE


init : Settings -> SettingsState
init settings_ =
    if Settings.hasAnyBordsConfigured settings_ then
        EditingBoard settings_

    else
        AddingBoard NewBoardConfig.default settings_



-- UTILITIES


boardConfigs : SettingsState -> SafeZipper BoardConfig
boardConfigs settingsState =
    Settings.boardConfigs <| settings settingsState


settings : SettingsState -> Settings
settings settingsState =
    case settingsState of
        AddingBoard _ settings_ ->
            settings_

        AddingColumn _ settings_ ->
            settings_

        ClosingPlugin settings_ ->
            settings_

        ClosingSettings settings_ ->
            settings_

        DeletingBoard settings_ ->
            settings_

        DeletingColumn _ settings_ ->
            settings_

        EditingBoard settings_ ->
            settings_

        EditingGlobalSettings settings_ ->
            settings_



-- TRANSFORM


addBoardRequested : SettingsState -> SettingsState
addBoardRequested settingsState =
    case settingsState of
        AddingBoard _ _ ->
            settingsState

        AddingColumn _ settings_ ->
            AddingBoard NewBoardConfig.default settings_

        ClosingPlugin settings_ ->
            AddingBoard NewBoardConfig.default settings_

        ClosingSettings settings_ ->
            AddingBoard NewBoardConfig.default settings_

        DeletingBoard settings_ ->
            AddingBoard NewBoardConfig.default settings_

        DeletingColumn _ settings_ ->
            AddingBoard NewBoardConfig.default settings_

        EditingBoard settings_ ->
            AddingBoard NewBoardConfig.default settings_

        EditingGlobalSettings settings_ ->
            AddingBoard NewBoardConfig.default settings_


addColumnRequested : SettingsState -> SettingsState
addColumnRequested settingsState =
    let
        columns : Columns
        columns =
            settingsState
                |> settings
                |> Settings.boardConfigs
                |> SafeZipper.current
                |> Maybe.map BoardConfig.columns
                |> Maybe.withDefault Columns.empty

        optionsForSelect : List OptionsForSelect
        optionsForSelect =
            Columns.optionsForSelect columns (NewColumnConfig "" "")

        selectedOption : String
        selectedOption =
            optionsForSelect
                |> LE.find .isSelected
                |> Maybe.map .value
                |> Maybe.withDefault "dated"
    in
    case settingsState of
        AddingBoard _ settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_

        AddingColumn _ _ ->
            settingsState

        ClosingPlugin settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_

        ClosingSettings settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_

        DeletingBoard settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_

        DeletingColumn _ settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_

        EditingBoard settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_

        EditingGlobalSettings settings_ ->
            AddingColumn (NewColumnConfig "" selectedOption) settings_


cancelCurrentState : SettingsState -> SettingsState
cancelCurrentState settingsState =
    case settingsState of
        AddingBoard _ settings_ ->
            if Settings.hasAnyBordsConfigured settings_ then
                init settings_

            else
                ClosingPlugin settings_

        AddingColumn _ settings_ ->
            EditingBoard settings_

        ClosingPlugin settings_ ->
            ClosingPlugin settings_

        ClosingSettings settings_ ->
            ClosingSettings settings_

        DeletingBoard settings_ ->
            EditingBoard settings_

        DeletingColumn _ settings_ ->
            EditingBoard settings_

        EditingBoard settings_ ->
            ClosingSettings settings_

        EditingGlobalSettings settings_ ->
            ClosingSettings settings_


confirmAddBoard : DefaultColumnNames -> SettingsState -> SettingsState
confirmAddBoard defaultColumnNames settingsState =
    case settingsState of
        AddingBoard c settings_ ->
            Settings.addBoard defaultColumnNames c settings_
                |> Settings.cleanupNames
                |> EditingBoard

        _ ->
            settingsState


confirmAddColumn : DefaultColumnNames -> SettingsState -> SettingsState
confirmAddColumn defaultColumnNames settingsState =
    case settingsState of
        AddingColumn c settings_ ->
            Settings.addColumn defaultColumnNames c settings_
                |> EditingBoard

        _ ->
            settingsState


confirmDelete : SettingsState -> SettingsState
confirmDelete settingsState =
    case settingsState of
        DeletingBoard settings_ ->
            init (Settings.deleteCurrentBoard settings_)

        DeletingColumn index settings_ ->
            EditingBoard (Settings.deleteColumn index settings_)

        _ ->
            settingsState


deleteBoardRequested : SettingsState -> SettingsState
deleteBoardRequested settingsState =
    case settingsState of
        AddingBoard _ settings_ ->
            DeletingBoard settings_

        AddingColumn _ settings_ ->
            DeletingBoard settings_

        ClosingPlugin settings_ ->
            DeletingBoard settings_

        ClosingSettings settings_ ->
            DeletingBoard settings_

        DeletingBoard _ ->
            settingsState

        DeletingColumn _ settings_ ->
            DeletingBoard settings_

        EditingBoard settings_ ->
            DeletingBoard settings_

        EditingGlobalSettings settings_ ->
            DeletingBoard settings_


deleteColumnRequested : Int -> SettingsState -> SettingsState
deleteColumnRequested index settingsState =
    case settingsState of
        AddingBoard _ settings_ ->
            DeletingColumn index settings_

        AddingColumn _ settings_ ->
            DeletingColumn index settings_

        ClosingPlugin settings_ ->
            DeletingColumn index settings_

        ClosingSettings settings_ ->
            DeletingColumn index settings_

        DeletingBoard settings_ ->
            DeletingColumn index settings_

        DeletingColumn _ settings_ ->
            DeletingColumn index settings_

        EditingBoard settings_ ->
            DeletingColumn index settings_

        EditingGlobalSettings settings_ ->
            DeletingColumn index settings_


editBoardAt : Int -> SettingsState -> SettingsState
editBoardAt index settingsState =
    case settingsState of
        AddingBoard _ settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        AddingColumn _ settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        ClosingPlugin settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        ClosingSettings settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        DeletingBoard settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        DeletingColumn _ settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        EditingBoard settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)

        EditingGlobalSettings settings_ ->
            EditingBoard (Settings.switchToBoard index settings_)


editGlobalSettings : SettingsState -> SettingsState
editGlobalSettings settingsState =
    case settingsState of
        AddingBoard _ settings_ ->
            EditingGlobalSettings settings_

        AddingColumn _ settings_ ->
            EditingGlobalSettings settings_

        ClosingPlugin settings_ ->
            EditingGlobalSettings settings_

        ClosingSettings settings_ ->
            EditingGlobalSettings settings_

        DeletingBoard settings_ ->
            EditingGlobalSettings settings_

        DeletingColumn _ settings_ ->
            EditingGlobalSettings settings_

        EditingBoard settings_ ->
            EditingGlobalSettings settings_

        EditingGlobalSettings _ ->
            settingsState


moveBoard : String -> BeaconPosition -> SettingsState -> SettingsState
moveBoard draggedId beaconPosition settingsState =
    mapSettings (Settings.moveBoard draggedId beaconPosition) settingsState


moveColumn : String -> BeaconPosition -> SettingsState -> SettingsState
moveColumn draggedId beaconPosition settingsState =
    mapSettings (Settings.moveColumn draggedId beaconPosition) settingsState



-- MAPPING


mapBoardBeingAdded : (NewBoardConfig -> NewBoardConfig) -> SettingsState -> SettingsState
mapBoardBeingAdded fn settingsState =
    case settingsState of
        AddingBoard c settings_ ->
            AddingBoard (fn c) settings_

        _ ->
            settingsState


mapBoardBeingEdited : (BoardConfig -> BoardConfig) -> SettingsState -> SettingsState
mapBoardBeingEdited fn settingsState =
    case settingsState of
        EditingBoard settings_ ->
            EditingBoard <| Settings.updateCurrentBoard fn settings_

        _ ->
            settingsState


mapColumnBeingAdded : (NewColumnConfig -> NewColumnConfig) -> SettingsState -> SettingsState
mapColumnBeingAdded fn settingsState =
    case settingsState of
        AddingColumn c settings_ ->
            AddingColumn (fn c) settings_

        _ ->
            settingsState


mapGlobalSettings : (GlobalSettings -> GlobalSettings) -> SettingsState -> SettingsState
mapGlobalSettings fn settingsState =
    case settingsState of
        EditingGlobalSettings settings_ ->
            EditingGlobalSettings (Settings.mapGlobalSettings fn settings_)

        _ ->
            settingsState



-- PRIVATE


mapSettings : (Settings -> Settings) -> SettingsState -> SettingsState
mapSettings fn settingsState =
    case settingsState of
        AddingBoard config settings_ ->
            AddingBoard config (fn settings_)

        AddingColumn config settings_ ->
            AddingColumn config (fn settings_)

        ClosingPlugin settings_ ->
            ClosingPlugin (fn settings_)

        ClosingSettings settings_ ->
            ClosingSettings (fn settings_)

        DeletingBoard settings_ ->
            DeletingBoard (fn settings_)

        DeletingColumn index settings_ ->
            DeletingColumn index (fn settings_)

        EditingBoard settings_ ->
            EditingBoard (fn settings_)

        EditingGlobalSettings settings_ ->
            EditingGlobalSettings (fn settings_)
