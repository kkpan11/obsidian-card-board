module Columns exposing
    ( Columns
    , addTaskList
    , completedCount
    , decoder
    , empty
    , encoder
    , fromList
    , includesOthers
    , includesUndated
    , legacyFromList
    , namedTagColumnTags
    , namedTagColumns
    , replaceNamedTagColumns
    , toList
    , toggleIncludeOthers
    , updateColumnNames
    )

import Column exposing (Column)
import Column.Completed as CompletedColumn exposing (CompletedColumn)
import Column.Dated as DatedColumn exposing (DatedColumn)
import Column.NamedTag as NamedTagColumn exposing (NamedTagColumn)
import Column.OtherTags as OtherTagsColumn exposing (OtherTagsColumn)
import Column.Undated as UndatedColumn exposing (UndatedColumn)
import ColumnNames exposing (ColumnNames)
import Date exposing (Date)
import List.Extra as LE
import Maybe.Extra as ME
import PlacementResult exposing (PlacementResult)
import TaskItem exposing (TaskItem)
import TaskList exposing (TaskList)
import TsJson.Decode as TsDecode
import TsJson.Encode as TsEncode



-- TYPES


type Columns
    = WithCompleted (List Column) CompletedColumn
    | WithoutCompleted (List Column)



-- CONSTRUCTION


empty : Columns
empty =
    WithoutCompleted []


fromList : List Column -> Columns
fromList columns =
    let
        completed : Maybe CompletedColumn
        completed =
            LE.find Column.isCompletedColumn columns
                |> Maybe.map Column.asCompletedColumn
                |> ME.join

        others : List Column
        others =
            LE.filterNot Column.isCompletedColumn columns
    in
    case completed of
        Nothing ->
            WithoutCompleted others

        Just completedColumn ->
            WithCompleted others completedColumn


legacyFromList : ColumnNames -> List Column -> Int -> Columns
legacyFromList columnNames columns completedCount_ =
    if completedCount_ > 0 then
        WithCompleted
            columns
            (CompletedColumn.init
                (ColumnNames.nameFor "completed" columnNames)
                (List.length columns)
                completedCount_
            )

    else
        WithoutCompleted columns



-- DECODE / ENCODE


decoder : TsDecode.Decoder Columns
decoder =
    TsDecode.list Column.decoder
        |> TsDecode.map fromList


encoder : TsEncode.Encoder Columns
encoder =
    TsEncode.map toList <| TsEncode.list Column.encoder



-- INFO


completedCount : Columns -> Int
completedCount columns =
    case columns of
        WithCompleted _ completedColumn ->
            CompletedColumn.limit completedColumn

        WithoutCompleted _ ->
            0


includesOthers : Columns -> Bool
includesOthers columns =
    columns
        |> toList
        |> List.any Column.isEnabledOthers


includesUndated : Columns -> Bool
includesUndated columns =
    columns
        |> toList
        |> List.any Column.isEnabledUndated


namedTagColumns : Columns -> List NamedTagColumn
namedTagColumns columns =
    columns
        |> toList
        |> List.map Column.asNamedTagColumn
        |> ME.values


namedTagColumnTags : Columns -> List String
namedTagColumnTags columns =
    columns
        |> toList
        |> List.map Column.tag
        |> ME.values



-- MODIFICATION


addTaskList : Date -> List String -> Columns -> TaskList -> Columns
addTaskList today tagsToHide columns taskList =
    taskList
        |> TaskList.foldl (addTaskItem today) columns
        |> setTagsToHide tagsToHide


replaceNamedTagColumns : List Column -> Columns -> Columns
replaceNamedTagColumns newColumns existingColumns =
    let
        withoutNamed : List Column
        withoutNamed =
            existingColumns
                |> toList
                |> LE.filterNot Column.isNamedTagColumn
    in
    fromList (withoutNamed ++ newColumns)


toggleIncludeOthers : Columns -> Columns
toggleIncludeOthers columns =
    if includesEnabledOthers columns then
        columns
            |> toList
            |> List.map Column.disableOthers
            |> fromList

    else if includesDisabledOthers columns then
        columns
            |> toList
            |> List.map Column.enableOthers
            |> fromList

    else
        columns
            |> toList
            |> List.append [ Column.otherTags "Others" <| namedTagColumnTags columns ]
            |> fromList


updateColumnNames : ColumnNames -> Columns -> Columns
updateColumnNames columnNames columns =
    columns
        |> toList
        |> List.map (Column.updateColumnNames columnNames)
        |> fromList



-- CONVERSION


toList : Columns -> List Column
toList columns =
    case columns of
        WithCompleted nonCompletedConfigs completedConfig ->
            nonCompletedConfigs
                |> insert (CompletedColumn.index completedConfig) (Column.completed completedConfig)

        WithoutCompleted nonCompletedConfigs ->
            nonCompletedConfigs



-- PRIVATE


addTaskItem : Date -> TaskItem -> Columns -> Columns
addTaskItem today taskItem columns =
    case columns of
        WithCompleted nonCompletedConfigs completedConfig ->
            let
                ( newConfigs, allPlacementResults ) =
                    addWithPlacement today taskItem nonCompletedConfigs
            in
            WithCompleted newConfigs
                (CompletedColumn.addTaskItem allPlacementResults taskItem completedConfig)

        WithoutCompleted nonCompletedConfigs ->
            let
                ( newConfigs, allPlacementResults ) =
                    addWithPlacement today taskItem nonCompletedConfigs
            in
            WithoutCompleted newConfigs


addWithPlacement : Date -> TaskItem -> List Column -> ( List Column, List PlacementResult )
addWithPlacement today taskItem initialConfigs =
    let
        fn : Column -> ( List Column, List PlacementResult ) -> ( List Column, List PlacementResult )
        fn thisConfig ( accumulatedConfigs, placementResults ) =
            Column.addTaskItem today taskItem thisConfig
                |> Tuple.mapFirst (\c -> c :: accumulatedConfigs)
                |> Tuple.mapSecond (\r -> r :: placementResults)
    in
    List.foldr fn ( [], [] ) initialConfigs


includesEnabledOthers : Columns -> Bool
includesEnabledOthers columns =
    columns
        |> toList
        |> List.any Column.isEnabledOthers


includesDisabledOthers : Columns -> Bool
includesDisabledOthers columns =
    columns
        |> toList
        |> List.any Column.isDisabledOthers


insert : Int -> a -> List a -> List a
insert i value list =
    List.take i list ++ [ value ] ++ List.drop i list


setTagsToHide : List String -> Columns -> Columns
setTagsToHide tags columns =
    case columns of
        WithCompleted nonCompletedConfigs completedConfig ->
            WithCompleted (List.map (Column.setTagsToHide tags) nonCompletedConfigs) (CompletedColumn.setTagsToHide tags completedConfig)

        WithoutCompleted nonCompletedConfigs ->
            WithoutCompleted (List.map (Column.setTagsToHide tags) nonCompletedConfigs)
