module Pages.Home exposing (Model, Msg, modelDecoder, subscriptions, update, view)

import DecoderUtil exposing (optionalPageDecoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Ports exposing (openFileSelectModal, requestOpenFile)


type alias ReadEntry =
    { name : String
    , path : String
    , lastReadPage : Int
    }


type alias Model =
    List ReadEntry


type Msg
    = ResumeReading String
    | OpenFileModal


modelDecoder : D.Decoder Model
modelDecoder =
    D.list <|
        D.map3 ReadEntry
            (D.field "name" D.string)
            (D.field "path" D.string)
            (optionalPageDecoder "lastReadPage")


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ResumeReading path ->
            ( model, requestOpenFile path )

        OpenFileModal ->
            ( model, openFileSelectModal )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


view : Model -> Html Msg
view model =
    let
        mapListItem : ReadEntry -> Html Msg
        mapListItem item =
            button [ onClick (ResumeReading item.path) ]
                [ h3 [] [ text item.name ]
                , span [] [ text <| String.fromInt item.lastReadPage ]
                , small [] [ text item.path ]
                ]

        readList : List (Html Msg)
        readList =
            List.map mapListItem model
    in
    div []
        [ h1 [] []
        , p [] []
        , button [ onClick OpenFileModal ] [ text "select file" ]
        , div [] readList
        ]
