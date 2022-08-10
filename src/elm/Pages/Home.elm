module Pages.Home exposing (Model, Msg, OutMsg(..), init, subscriptions, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Payloads
import Ports exposing (onHistoryResult, requestFileSelectModal, requestHistory)
import Stateful exposing (Stateful(..))


type alias Model =
    Payloads.PortStateful Payloads.History


type Msg
    = OpenFile String
    | RequestHistory
    | HistoryResult (Payloads.PortResult Payloads.History)
    | OpenFileModal


type OutMsg
    = ResumeReading String
    | NoOp


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, requestHistory )


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case ( model, msg ) of
        ( NotAsked, RequestHistory ) ->
            ( Loading, requestHistory, NoOp )

        ( Loading, HistoryResult (Ok payload) ) ->
            ( Stateful.Success payload, Cmd.none, NoOp )

        ( Loading, HistoryResult (Err err) ) ->
            ( Stateful.Failure err, Cmd.none, NoOp )

        ( Success _, OpenFile path ) ->
            ( model, Cmd.none, ResumeReading path )

        ( Failure _, RequestHistory ) ->
            ( Loading, requestHistory, NoOp )

        ( _, OpenFileModal ) ->
            ( model, requestFileSelectModal, NoOp )

        _ ->
            ( model, Cmd.none, NoOp )


subscriptions : Model -> Sub Msg
subscriptions _ =
    onHistoryResult HistoryResult


view : Model -> Html Msg
view model =
    let
        extractFilename : String -> String
        extractFilename path =
            case List.reverse <| String.indexes "/" path of
                barIndex :: _ ->
                    String.slice (barIndex + 1) (String.length path) path

                _ ->
                    path

        historyItem : Payloads.HistoryEntry -> Html Msg
        historyItem item =
            button [ onClick (OpenFile item.path) ]
                [ h3 [] [ text <| Maybe.withDefault (extractFilename item.path) item.title ]
                , span [] [ text item.page ]
                , small [] [ text item.path ]
                ]

        content : Html Msg
        content =
            case model of
                NotAsked ->
                    button [ onClick RequestHistory ] [ text "Load History" ]

                Loading ->
                    p [] [ text "loading" ]

                Success payload ->
                    if List.isEmpty payload then
                        p [] [ text "No history" ]

                    else
                        ul [] <| List.map historyItem payload

                Failure err ->
                    div []
                        [ h1 [] [ text err.code ]
                        , p [] [ text err.message ]
                        , button [ onClick RequestHistory ] [ text "Try Again" ]
                        ]
    in
    div []
        [ button [ onClick OpenFileModal ] [ text "select file" ]
        , content
        ]
