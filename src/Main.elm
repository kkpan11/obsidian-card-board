module Main exposing (main)

import BoardConfig exposing (BoardConfig)
import Browser
import Card exposing (Card)
import CardBoardSettings exposing (Settings)
import Date exposing (Date)
import DateBoard
import FeatherIcons
import Html exposing (Html)
import Html.Attributes exposing (checked, class, hidden, id, placeholder, selected, type_, value)
import Html.Events exposing (onClick, onInput)
import Html.Keyed
import InteropDefinitions
import InteropPorts
import Json.Decode as JD
import MarkdownFile exposing (MarkdownFile)
import Model exposing (Model, State)
import Page.Settings as SettingsPage
import Panel exposing (Panel)
import Panels exposing (Panels)
import Parser
import SafeZipper exposing (SafeZipper)
import String
import TagBoard
import Task
import TaskItem exposing (TaskItem)
import TaskList exposing (TaskList)
import Time
import TimeWithZone exposing (TimeWithZone)


main : Program JD.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : JD.Value -> ( Model, Cmd Msg )
init flags =
    case flags |> InteropPorts.decodeFlags of
        Err _ ->
            ( Model.default, Cmd.none )

        Ok okFlags ->
            let
                boardConfigs =
                    SafeZipper.fromList <| CardBoardSettings.boardConfigs okFlags.settings
            in
            ( { boardConfigs = boardConfigs
              , configBeingEdited = Model.NotEditing
              , taskList = Model.Waiting
              , timeWithZone =
                    { now = Time.millisToPosix okFlags.now
                    , zone = Time.customZone okFlags.zone []
                    }
              }
                |> Model.forceAddWhenNoBoards boardConfigs
            , Task.perform ReceiveTime <| Task.map2 Tuple.pair Time.here Time.now
            )


hasLoaded : State TaskList -> Bool
hasLoaded taskList =
    case taskList of
        Model.Loaded _ ->
            True

        _ ->
            False



-- UPDATE


type Msg
    = BadInputFromTypeScript JD.Error
    | GotSettingsPageMsg SettingsPage.Msg
    | InitCompleted
    | ReceiveTime ( Time.Zone, Time.Posix )
    | SettingsClicked
    | SettingsUpdated (List BoardConfig)
    | TabSelected Int
    | TaskItemEditClicked String
    | TaskItemDeleteClicked String
    | TaskItemToggled String
    | Tick Time.Posix
    | VaultFileAdded MarkdownFile
    | VaultFileDeleted String
    | VaultFileRenamed ( String, String )
    | VaultFileUpdated MarkdownFile


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( BadInputFromTypeScript _, _ ) ->
            -- Debug.todo <| Debug.toString error
            ( model, Cmd.none )

        ( GotSettingsPageMsg subMsg, _ ) ->
            SettingsPage.update subMsg model
                |> updateWith GotSettingsPageMsg

        ( InitCompleted, _ ) ->
            case model.taskList of
                Model.Waiting ->
                    ( { model | taskList = Model.Loaded TaskList.empty }, Cmd.none )

                Model.Loading taskList ->
                    let
                        cards =
                            taskList
                                |> Panels.init model.boardConfigs
                                |> Panels.cards model.timeWithZone
                    in
                    ( { model | taskList = Model.Loaded taskList }
                    , Cmd.batch
                        [ InteropPorts.displayTaskMarkdown cards
                        , InteropPorts.addHoverToCardEditButtons cards
                        ]
                    )

                Model.Loaded _ ->
                    ( model, Cmd.none )

        ( ReceiveTime ( zone, posix ), _ ) ->
            ( { model
                | timeWithZone =
                    { zone = zone
                    , now = posix
                    }
              }
            , Cmd.none
            )

        ( SettingsClicked, _ ) ->
            ( { model | configBeingEdited = Model.Editing model.boardConfigs }, Cmd.none )

        ( SettingsUpdated newSettings, _ ) ->
            case model.taskList of
                Model.Waiting ->
                    ( { model | boardConfigs = SafeZipper.fromList newSettings }, Cmd.none )

                Model.Loading _ ->
                    ( { model | boardConfigs = SafeZipper.fromList newSettings }, Cmd.none )

                Model.Loaded taskList ->
                    let
                        newConfigs =
                            SafeZipper.fromList newSettings
                                |> SafeZipper.atIndex newIndex

                        newIndex =
                            model.boardConfigs
                                |> SafeZipper.currentIndex
                                |> Maybe.withDefault 0

                        cards =
                            taskList
                                |> Panels.init newConfigs
                                |> Panels.cards model.timeWithZone
                    in
                    ( { model | boardConfigs = newConfigs }
                    , Cmd.batch
                        [ InteropPorts.displayTaskMarkdown cards
                        , InteropPorts.addHoverToCardEditButtons cards
                        ]
                    )

        ( TabSelected tabIndex, _ ) ->
            ( { model | boardConfigs = SafeZipper.atIndex tabIndex model.boardConfigs }, Cmd.none )

        ( TaskItemDeleteClicked id, _ ) ->
            case model.taskList of
                Model.Loaded taskList ->
                    case TaskList.taskFromId id taskList of
                        Just matchingItem ->
                            ( model
                            , InteropPorts.deleteTodo
                                { filePath = TaskItem.filePath matchingItem
                                , lineNumber = TaskItem.lineNumber matchingItem
                                , originalText = TaskItem.originalText matchingItem
                                }
                            )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( TaskItemEditClicked id, _ ) ->
            case model.taskList of
                Model.Loaded taskList ->
                    case TaskList.taskFromId id taskList of
                        Just matchingItem ->
                            ( model
                            , InteropPorts.openTodoSourceFile
                                { filePath = TaskItem.filePath matchingItem
                                , lineNumber = TaskItem.lineNumber matchingItem
                                , originalText = TaskItem.originalText matchingItem
                                }
                            )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( TaskItemToggled id, _ ) ->
            case model.taskList of
                Model.Loaded taskList ->
                    case TaskList.taskContainingId id taskList of
                        Just matchingItem ->
                            ( model
                            , InteropPorts.rewriteTodos
                                model.timeWithZone
                                (TaskItem.filePath matchingItem)
                                (TaskItem.tasksToToggle id model.timeWithZone matchingItem)
                            )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( Tick time, _ ) ->
            ( { model | timeWithZone = TimeWithZone.now time model.timeWithZone }
            , Cmd.none
            )

        ( VaultFileAdded markdownFile, _ ) ->
            let
                newTaskItems =
                    TaskList.fromMarkdown markdownFile.filePath markdownFile.fileDate markdownFile.fileContents

                cards =
                    newTaskItems
                        |> Panels.init model.boardConfigs
                        |> Panels.cards model.timeWithZone
            in
            ( addTaskItems model newTaskItems
            , if hasLoaded model.taskList then
                Cmd.batch
                    [ InteropPorts.displayTaskMarkdown cards
                    , InteropPorts.addHoverToCardEditButtons cards
                    ]

              else
                Cmd.none
            )

        ( VaultFileDeleted filePath, _ ) ->
            ( deleteItemsFromFile model filePath, Cmd.none )

        ( VaultFileRenamed ( oldPath, newPath ), _ ) ->
            let
                updatedTaskItems =
                    rePathedTaskItems oldPath newPath model.taskList

                cards =
                    updatedTaskItems
                        |> Panels.init model.boardConfigs
                        |> Panels.cards model.timeWithZone
            in
            ( updateTaskItems model oldPath updatedTaskItems
            , if hasLoaded model.taskList then
                Cmd.batch
                    [ InteropPorts.displayTaskMarkdown cards
                    , InteropPorts.addHoverToCardEditButtons cards
                    ]

              else
                Cmd.none
            )

        ( VaultFileUpdated markdownFile, _ ) ->
            let
                updatedTaskItems =
                    TaskList.fromMarkdown markdownFile.filePath markdownFile.fileDate markdownFile.fileContents

                cards =
                    updatedTaskItems
                        |> Panels.init model.boardConfigs
                        |> Panels.cards model.timeWithZone
            in
            ( updateTaskItems model markdownFile.filePath updatedTaskItems
            , if hasLoaded model.taskList then
                Cmd.batch
                    [ InteropPorts.displayTaskMarkdown cards
                    , InteropPorts.addHoverToCardEditButtons cards
                    ]

              else
                Cmd.none
            )


updateWith : (subMsg -> Msg) -> ( Model, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toMsg ( model, subCmd ) =
    ( model, Cmd.map toMsg subCmd )


rePathedTaskItems : String -> String -> State TaskList -> TaskList
rePathedTaskItems oldPath newPath taskList =
    let
        rePathedItems : TaskList -> TaskList
        rePathedItems list =
            list
                |> TaskList.filter needsRename
                |> TaskList.map (TaskItem.updateFilePath newPath)

        needsRename : TaskItem -> Bool
        needsRename item =
            TaskItem.filePath item == oldPath
    in
    case taskList of
        Model.Waiting ->
            TaskList.empty

        Model.Loading currentList ->
            rePathedItems currentList

        Model.Loaded currentList ->
            rePathedItems currentList


deleteItemsFromFile : Model -> String -> Model
deleteItemsFromFile model filePath =
    case model.taskList of
        Model.Waiting ->
            model

        Model.Loading currentList ->
            { model | taskList = Model.Loading (TaskList.removeForFile filePath currentList) }

        Model.Loaded currentList ->
            { model | taskList = Model.Loaded (TaskList.removeForFile filePath currentList) }


addTaskItems : Model -> TaskList -> Model
addTaskItems model taskList =
    case model.taskList of
        Model.Waiting ->
            { model | taskList = Model.Loading taskList }

        Model.Loading currentList ->
            { model | taskList = Model.Loading (TaskList.append currentList taskList) }

        Model.Loaded currentList ->
            { model | taskList = Model.Loaded (TaskList.append currentList taskList) }


updateTaskItems : Model -> String -> TaskList -> Model
updateTaskItems model filePath updatedList =
    case model.taskList of
        Model.Waiting ->
            { model | taskList = Model.Loading updatedList }

        Model.Loading currentList ->
            { model | taskList = Model.Loading (TaskList.replaceForFile filePath updatedList currentList) }

        Model.Loaded currentList ->
            { model | taskList = Model.Loaded (TaskList.replaceForFile filePath updatedList currentList) }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Time.every 1000 Tick
        , InteropPorts.toElm
            |> Sub.map
                (\result ->
                    case result of
                        Ok toElm ->
                            case toElm of
                                InteropDefinitions.FileAdded markdownFile ->
                                    VaultFileAdded markdownFile

                                InteropDefinitions.FileDeleted filePath ->
                                    VaultFileDeleted filePath

                                InteropDefinitions.FileRenamed oldAndNewPath ->
                                    VaultFileRenamed oldAndNewPath

                                InteropDefinitions.FileUpdated markdownFile ->
                                    VaultFileUpdated markdownFile

                                InteropDefinitions.InitCompleted ->
                                    InitCompleted

                                InteropDefinitions.SettingsUpdated newSettings ->
                                    SettingsUpdated newSettings.boardConfigs

                        Err error ->
                            BadInputFromTypeScript error
                )
        ]



-- VIEW


view : Model -> Html Msg
view model =
    case model.taskList of
        Model.Loaded taskList ->
            let
                panels =
                    Panels.init model.boardConfigs taskList

                currentIndex =
                    Panels.currentIndex panels
            in
            Html.div [ class "card-board" ]
                [ Html.div [ class "card-board-container" ]
                    [ Html.ul [ class "card-board-tab-list" ]
                        (tabHeaders currentIndex panels)
                    , Html.div [ class "card-board-panels" ]
                        (Panels.panels panels
                            |> SafeZipper.indexedMapSelectedAndRest (selectedPanelView model.timeWithZone) (panelView model.timeWithZone)
                            |> SafeZipper.toList
                        )
                    ]
                , SettingsPage.dialogs model.configBeingEdited
                    |> Html.map GotSettingsPageMsg
                ]

        _ ->
            Html.text "Loading tasks...."


tabHeaders : Maybe Int -> Panels -> List (Html Msg)
tabHeaders currentIndex panels =
    let
        beforeHeaderClass =
            tabHeaderClass currentIndex -1

        beforeFirst =
            Html.li [ class <| "card-board-pre-tabs" ++ beforeHeaderClass ]
                [ Html.div
                    [ class "card-board-tabs-inner"
                    , onClick SettingsClicked
                    ]
                    [ FeatherIcons.settings
                        |> FeatherIcons.withSize 1
                        |> FeatherIcons.withSizeUnit "em"
                        |> FeatherIcons.toHtml []
                    ]
                ]

        afterHeaderClass =
            tabHeaderClass currentIndex (Panels.length panels)

        afterLast =
            Html.li [ class <| "card-board-post-tabs" ++ afterHeaderClass ]
                [ Html.div [ class "card-board-tabs-inner" ]
                    [ Html.text "" ]
                ]

        tabs =
            Panels.tabTitles panels
                |> SafeZipper.indexedMapSelectedAndRest selectedTabHeader (tabHeader currentIndex)
                |> SafeZipper.toList
    in
    beforeFirst :: List.append tabs [ afterLast ]


selectedTabHeader : Int -> String -> Html Msg
selectedTabHeader _ title =
    Html.li [ class "card-board-tab-title is-active" ]
        [ Html.div [ class "card-board-tabs-inner" ]
            [ Html.text <| title ]
        ]


tabHeader : Maybe Int -> Int -> String -> Html Msg
tabHeader currentIndex index title =
    let
        headerClass =
            tabHeaderClass currentIndex index
    in
    Html.li
        [ class ("card-board-tab-title" ++ headerClass)
        , onClick <| TabSelected index
        ]
        [ Html.div [ class "card-board-tabs-inner" ]
            [ Html.text <| title ]
        ]


tabHeaderClass : Maybe Int -> Int -> String
tabHeaderClass currentIndex index =
    case currentIndex of
        Just i ->
            if index == i - 1 then
                " is-before-active"

            else if index == i + 1 then
                " is-after-active"

            else
                ""

        Nothing ->
            ""


panelView : TimeWithZone -> Int -> Panel -> Html Msg
panelView timeWithZone index panel =
    Html.div
        [ class "card-board-panel"
        , hidden True
        ]
        [ Html.div [ class "card-board-columns" ]
            (panel
                |> Panel.columns timeWithZone index
                |> List.map (\( n, cs ) -> column timeWithZone n cs)
            )
        ]


selectedPanelView : TimeWithZone -> Int -> Panel -> Html Msg
selectedPanelView timeWithZone index panel =
    Html.div [ class "card-board-panel" ]
        [ Html.div [ class "card-board-columns" ]
            (panel
                |> Panel.columns timeWithZone index
                |> List.map (\( n, cs ) -> column timeWithZone n cs)
            )
        ]


column : TimeWithZone -> String -> List Card -> Html Msg
column timeWithZone title cards =
    Html.div [ class "card-board-column" ]
        [ Html.div [ class "card-board-column-header" ]
            [ Html.text title ]
        , Html.Keyed.ul [ class "card-board-column-list" ]
            (List.map (cardView timeWithZone) cards)
        ]


cardView : TimeWithZone -> Card -> ( String, Html Msg )
cardView timeWithZone card =
    let
        cardId =
            Card.id card

        taskItem =
            Card.taskItem card

        taskItemId =
            Card.taskItemId card

        highlightAreaClass =
            case Card.highlight timeWithZone card of
                Card.HighlightCritical ->
                    "critical"

                Card.HighlightGood ->
                    "good"

                Card.HighlightImportant ->
                    "important"

                Card.HighlightNone ->
                    ""
    in
    Html.li [ class "card-board-card cm-s-obsidian markdown-preview-view" ]
        [ Html.div [ class ("card-board-card-highlight-area " ++ highlightAreaClass) ]
            []
        , Html.div [ class "card-board-card-content-area" ]
            [ Html.input
                [ type_ "checkbox"
                , class "task-list-item-checkbox"
                , onClick <| TaskItemToggled taskItemId
                , checked <| TaskItem.isCompleted taskItem
                ]
                []
            , Html.div [ class "card-board-card-title", id cardId ]
                []
            , cardTagsView (TaskItem.tags taskItem)
                |> when (TaskItem.hasTags taskItem)
            , subtasksView (Card.subtasks card)
                |> when (TaskItem.hasSubtasks taskItem)
            , notesView (Card.notesId card)
                |> when (TaskItem.hasNotes taskItem)
            , Html.div [ class "card-board-card-footer-area" ]
                [ taskDueDate (TaskItem.due taskItem)
                    |> when (TaskItem.isDated taskItem)
                , cardActionButtons taskItemId (Card.editButtonId card)
                ]
            ]
        ]
        |> Tuple.pair cardId


cardTagsView : List String -> Html Msg
cardTagsView tags =
    Html.div [ class "card-board-card-tag-area" ]
        (List.map cardTagView tags)


cardTagView : String -> Html Msg
cardTagView tagText =
    Html.div [ class ("card-board-card-tag tag-" ++ String.replace "/" "-" tagText) ]
        [ Html.span [ class "cm-hashtag-begin cm-hashtag" ]
            [ Html.text "#" ]
        , Html.span [ class "cm-list-1 cm-hashtag cm-hashtag-end" ]
            [ Html.text tagText ]
        , Html.span [ class "cm-list-1" ]
            [ Html.text " " ]
        ]


notesView : String -> Html Msg
notesView notesId =
    Html.div [ class "card-board-card-notes-area", id notesId ]
        []


subtasksView : List ( String, TaskItem ) -> Html Msg
subtasksView subtasks =
    Html.div [ class "card-board-card-subtasks-area" ]
        [ Html.ul [ class "contains-task-list" ]
            (List.map subtaskView subtasks)
        ]


subtaskView : ( String, TaskItem ) -> Html Msg
subtaskView ( uniqueId, subtask ) =
    Html.li [ class "card-board-card-subtask task-list-item" ]
        [ Html.input
            [ type_ "checkbox"
            , class "task-list-item-checkbox"
            , onClick <| TaskItemToggled <| TaskItem.id subtask
            , checked <| TaskItem.isCompleted subtask
            ]
            []
        , Html.div [ class "card-board-card-title", id uniqueId ]
            []
        ]


taskDueDate : Maybe Date -> Html Msg
taskDueDate dueDate =
    Html.div [ class "card-board-card-action-area-due" ]
        [ Html.text ("Due: " ++ dueDateString dueDate)
        ]


dueDateString : Maybe Date -> String
dueDateString dueDate =
    case dueDate of
        Just date ->
            Date.format "E, MMM ddd" date

        Nothing ->
            "n/a"


cardActionButtons : String -> String -> Html Msg
cardActionButtons taskItemId editButtonId =
    Html.div [ class "card-board-card-action-area-buttons" ]
        [ Html.div
            [ class "card-board-card-action-area-button"
            , onClickWithPreventDefault <| TaskItemEditClicked taskItemId
            , id editButtonId
            ]
            [ FeatherIcons.edit
                |> FeatherIcons.withSize 1
                |> FeatherIcons.withSizeUnit "em"
                |> FeatherIcons.toHtml []
            ]
        , Html.div
            [ class "card-board-card-action-area-button"
            , onClick <| TaskItemDeleteClicked taskItemId
            ]
            [ FeatherIcons.trash
                |> FeatherIcons.withSize 1
                |> FeatherIcons.withSizeUnit "em"
                |> FeatherIcons.toHtml []
            ]
        ]



-- HELPERS


onClickWithPreventDefault : msg -> Html.Attribute msg
onClickWithPreventDefault msg =
    Html.Events.preventDefaultOn "click" (JD.map alwaysPreventDefault (JD.succeed msg))


alwaysPreventDefault : msg -> ( msg, Bool )
alwaysPreventDefault msg =
    ( msg, True )


empty : Html Msg
empty =
    Html.text ""


when : Bool -> Html Msg -> Html Msg
when shouldRender html =
    if shouldRender then
        html

    else
        empty
