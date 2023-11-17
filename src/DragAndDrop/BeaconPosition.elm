module DragAndDrop.BeaconPosition exposing
    ( BeaconPosition(..)
    , decoder
    , encoder
    , uniqueId
    )

import Json.Encode as JE
import TsJson.Decode as TsDecode



-- TYPES


type BeaconPosition
    = Before String
    | After String



-- ENCODE / DECODE


decoder : TsDecode.Decoder BeaconPosition
decoder =
    TsDecode.oneOf
        [ toElmBeacon "after" After TsDecode.string
        , toElmBeacon "before" Before TsDecode.string
        ]


encoder : BeaconPosition -> JE.Value
encoder beaconPosition =
    let
        ( positionStr, identifierString ) =
            case beaconPosition of
                After tabIndex ->
                    ( "after", tabIndex )

                Before tabIndex ->
                    ( "before", tabIndex )
    in
    JE.object
        [ ( "position", JE.string positionStr )
        , ( "uniqueId", JE.string identifierString )
        ]



-- UTILS


uniqueId : BeaconPosition -> String
uniqueId beaconPosition =
    case beaconPosition of
        Before id ->
            id

        After id ->
            id



-- PRIVATE


toElmBeacon : String -> (value -> a) -> TsDecode.Decoder value -> TsDecode.Decoder a
toElmBeacon tagName constructor decoder_ =
    TsDecode.field "position" (TsDecode.literal constructor (JE.string tagName))
        |> TsDecode.andMap (TsDecode.field "uniqueId" decoder_)
