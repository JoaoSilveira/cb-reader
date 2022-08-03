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
        historyItem : Payloads.HistoryEntry -> Html Msg
        historyItem item =
            button [ onClick (OpenFile item.path) ]
                [ h3 [] [ text item.title ]
                , span [] [ text <| String.fromInt item.page ]
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
                        [ p [] [ text err.message ]
                        , button [ onClick RequestHistory ] [ text "Try Again" ]
                        ]
    in
    div []
        [ button [ onClick OpenFileModal ] [ text "select file" ]
        , content
        ]
