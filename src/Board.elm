module Board exposing
    ( Board
    , columns
    , id
    , init
    )

import BoardConfig exposing (BoardConfig)
import Card exposing (Card)
import CollapsedColumns exposing (CollapsedColumns)
import ColumnConfig exposing (ColumnConfig)
import ColumnConfigs
import ColumnNames exposing (ColumnNames)
import Date exposing (Date)
import Filter exposing (Filter, Polarity, Scope)
import TaskItem exposing (TaskItem)
import TaskList exposing (TaskList)



-- TYPES


type Board
    = Board String ColumnNames BoardConfig TaskList



-- CONSTRUCTION


init : String -> ColumnNames -> BoardConfig -> TaskList -> Board
init uniqueId columnNames config taskList =
    Board uniqueId columnNames config taskList



-- INFO


columns : Bool -> Date -> Board -> List ColumnConfig
columns ignoreFileNameDates today ((Board _ columnNames config taskList) as board) =
    case config of
        BoardConfig.DateBoardConfig dateBoardConfig ->
            taskList
                |> filterTaskList config
                |> configureDueDates ignoreFileNameDates
                |> ColumnConfigs.addTaskList today dateBoardConfig.columnConfigs
                |> ColumnConfigs.toList

        BoardConfig.TagBoardConfig tagBoardConfig ->
            taskList
                |> filterTaskList config
                |> configureDueDates ignoreFileNameDates
                |> ColumnConfigs.addTaskList today tagBoardConfig.columnConfigs
                |> ColumnConfigs.toList


id : Board -> String
id (Board uniqueId _ config _) =
    uniqueId ++ ":" ++ String.replace " " "_" (BoardConfig.title config)



-- PRIVATE


configureDueDates : Bool -> TaskList -> TaskList
configureDueDates ignoreFileNameDates taskList =
    if ignoreFileNameDates then
        TaskList.map TaskItem.removeFileNameDate taskList

    else
        taskList


filterTaskList : BoardConfig -> TaskList -> TaskList
filterTaskList config taskList =
    let
        filters : List Filter
        filters =
            BoardConfig.filters config

        filterPolarity : Polarity
        filterPolarity =
            BoardConfig.filterPolarity config

        filterScope : Scope
        filterScope =
            BoardConfig.filterScope config
    in
    taskList
        |> filterByFilesystem filterPolarity filterScope filters
        |> filterByTag filterPolarity filterScope filters


filterByFilesystem : Polarity -> Scope -> List Filter -> TaskList -> TaskList
filterByFilesystem polarity scope filters taskList =
    List.filter (\f -> Filter.filterType f == "Files" || Filter.filterType f == "Paths") filters
        |> applyFilters taskList polarity scope


filterByTag : Polarity -> Scope -> List Filter -> TaskList -> TaskList
filterByTag polarity scope filters taskList =
    List.filter (\f -> Filter.filterType f == "Tags") filters
        |> applyFilters taskList polarity scope


applyFilters : TaskList -> Polarity -> Scope -> List Filter -> TaskList
applyFilters taskList polarity scope filters =
    let
        operator : Bool -> Bool
        operator =
            case polarity of
                Filter.Allow ->
                    identity

                Filter.Deny ->
                    not

        filterMode : (a -> Bool) -> List a -> Bool
        filterMode =
            case polarity of
                Filter.Allow ->
                    List.any

                Filter.Deny ->
                    List.all
    in
    if List.isEmpty filters then
        taskList

    else
        TaskList.filter (\t -> filterMode (operator << Filter.isAllowed scope t) filters) taskList
