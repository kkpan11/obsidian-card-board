module Helpers.BoardHelpers exposing
    ( defaultDateBoardConfig
    , defaultTagBoardConfig
    , exampleBoardConfig
    , exampleDateBoardConfig
    , exampleTagBoardConfig
    , tasksInColumn
    )

import BoardConfig exposing (BoardConfig)
import DateBoard
import Filter
import Parser
import TagBoard
import TaskItem exposing (TaskItem)
import TaskList exposing (TaskList)


defaultDateBoardConfig : DateBoard.Config
defaultDateBoardConfig =
    { completedCount = 0
    , filters = []
    , includeUndated = False
    , title = "Date Board Title"
    }


exampleBoardConfig : BoardConfig
exampleBoardConfig =
    BoardConfig.TagBoardConfig exampleTagBoardConfig


exampleDateBoardConfig : DateBoard.Config
exampleDateBoardConfig =
    { completedCount = 12
    , filters = [ Filter.PathFilter "a/path", Filter.PathFilter "b/path", Filter.TagFilter "tag1", Filter.TagFilter "tag2" ]
    , includeUndated = False
    , title = "Date Board Title"
    }


defaultTagBoardConfig : TagBoard.Config
defaultTagBoardConfig =
    { columns = []
    , completedCount = 0
    , filters = []
    , includeOthers = False
    , includeUntagged = False
    , title = "Tag Board Title"
    }


exampleTagBoardConfig : TagBoard.Config
exampleTagBoardConfig =
    { columns = [ { tag = "foo", displayTitle = "bar" } ]
    , completedCount = 6
    , filters = [ Filter.PathFilter "a", Filter.PathFilter "b", Filter.TagFilter "t1", Filter.TagFilter "t2" ]
    , includeOthers = False
    , includeUntagged = True
    , title = "Tag Board Title"
    }


tasksInColumn : String -> List ( String, List TaskItem ) -> List TaskItem
tasksInColumn columnName tasksInColumns =
    tasksInColumns
        |> List.filter (\( c, _ ) -> c == columnName)
        |> List.concatMap Tuple.second
