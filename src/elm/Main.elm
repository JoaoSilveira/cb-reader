module Main exposing (Model(..), Msg(..), init, main, update, view)

import Browser
import Browser.Events
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Pages.Home
import Pages.Reading
import Ports exposing (onFileSelected, requestFileSelectModal)
import Stateful


main : Program D.Value Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type Model
    = HomePageModel Pages.Home.Model
    | ReadPageModel Pages.Reading.Model


type alias KeyboadData =
    { key : String
    , ctrl : Bool
    , alt : Bool
    , shift : Bool
    , meta : Bool
    }


init : D.Value -> ( Model, Cmd Msg )
init flag =
    let
        screenDecoderResolver : String -> D.Decoder ( Model, Cmd Msg )
        screenDecoderResolver screen =
            if screen == "home" then
                D.succeed <| mapUpdate HomePageModel HomePageMsg (Pages.Home.init ())

            else if screen == "read" then
                D.map
                    (Pages.Reading.init >> mapUpdate ReadPageModel ReadPageMsg)
                    D.string

            else
                D.fail ""

        decodeResult =
            D.decodeValue
                (D.field "screen" D.string
                    |> D.andThen screenDecoderResolver
                )
                flag
    in
    Result.withDefault
        ( HomePageModel Stateful.NotAsked, Cmd.none )
        decodeResult


type Msg
    = HomePageMsg Pages.Home.Msg
    | ReadPageMsg Pages.Reading.Msg
    | OpenFile String
    | CloseFile
    | OpenFileModal
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( HomePageMsg homeMsg, HomePageModel homeModel ) ->
            case Pages.Home.update homeMsg homeModel of
                ( _, _, Pages.Home.ResumeReading path ) ->
                    mapUpdate ReadPageModel ReadPageMsg <| Pages.Reading.init path

                ( newModel, newMsg, _ ) ->
                    mapUpdate HomePageModel HomePageMsg ( newModel, newMsg )

        ( ReadPageMsg readMsg, ReadPageModel readModel ) ->
            Pages.Reading.update readMsg readModel
                |> mapUpdate ReadPageModel ReadPageMsg

        ( OpenFile path, _ ) ->
            mapUpdate ReadPageModel ReadPageMsg <| Pages.Reading.init path

        ( CloseFile, _ ) ->
            ( HomePageModel Stateful.NotAsked, Cmd.none )

        ( OpenFileModal, _ ) ->
            ( model, requestFileSelectModal )

        ( _, _ ) ->
            ( model, Cmd.none )


mapUpdate : (subModel -> Model) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
mapUpdate toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )


keyboardDataDecoder : D.Decoder KeyboadData
keyboardDataDecoder =
    D.map5
        KeyboadData
        (D.field "key" D.string)
        (D.field "ctrlKey" D.bool)
        (D.field "altKey" D.bool)
        (D.field "shiftKey" D.bool)
        (D.field "metaKey" D.bool)


parseKeyboardShortcut : String -> KeyboadData
parseKeyboardShortcut shortcut =
    let
        initialShortcut : KeyboadData
        initialShortcut =
            { key = "", ctrl = False, alt = False, shift = False, meta = False }

        foldShortcut : String -> KeyboadData -> KeyboadData
        foldShortcut key short =
            case key of
                "ctrl" ->
                    { short | ctrl = True }

                "shift" ->
                    { short | shift = True }

                "alt" ->
                    { short | alt = True }

                "meta" ->
                    { short | meta = True }

                "win" ->
                    { short | meta = True }

                _ ->
                    { short | key = key }
    in
    String.split "+" shortcut
        |> List.map String.toLower
        |> List.map String.trim
        |> List.foldl foldShortcut initialShortcut


shortcutMatchWithString : KeyboadData -> String -> Bool
shortcutMatchWithString pressed shortcut =
    let
        shortcutData =
            parseKeyboardShortcut shortcut
    in
    pressed.key == shortcutData.key && pressed.ctrl == shortcutData.ctrl && pressed.alt == shortcutData.alt && pressed.meta == shortcutData.meta && pressed.shift == shortcutData.shift


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        modelSub =
            case model of
                HomePageModel homeModel ->
                    Sub.map HomePageMsg <| Pages.Home.subscriptions homeModel

                ReadPageModel readModel ->
                    Sub.map ReadPageMsg <| Pages.Reading.subscriptions readModel

        keyDecoder =
            let
                shortcutHandler shortcut =
                    let
                        matchesWith =
                            shortcutMatchWithString shortcut
                    in
                    if matchesWith "Escape" then
                        CloseFile

                    else if matchesWith "ctrl+O" then
                        OpenFileModal

                    else
                        NoOp
            in
            keyboardDataDecoder
                |> D.andThen (shortcutHandler >> D.succeed)
    in
    Sub.batch
        [ modelSub
        , onFileSelected OpenFile
        , Browser.Events.onKeyDown keyDecoder
        ]


view : Model -> Html Msg
view model =
    case model of
        HomePageModel homeModel ->
            Html.map
                HomePageMsg
                (Pages.Home.view homeModel)

        ReadPageModel readModel ->
            Html.map
                ReadPageMsg
                (Pages.Reading.view readModel)
