module Main exposing (main)

import Browser
import Html exposing (Html)
import Ports exposing (DataForElm)


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    String


init : String -> ( Model, Cmd Msg )
init displayText =
    ( displayText
    , Cmd.none
    )



-- UPDATE


type Msg
    = DataFromTypeScript DataForElm
    | LogError String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( DataFromTypeScript dataForElm, _ ) ->
            case dataForElm of
                Ports.MarkdownToParse markdownFile ->
                    ( markdownFile.fileContents, Cmd.none )

        ( LogError error, _ ) ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Ports.receiveDataFromTypescript DataFromTypeScript LogError



-- VIEW


view : Model -> Html Msg
view model =
    Html.text model
