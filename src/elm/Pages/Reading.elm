module Pages.Reading exposing (Model, Msg, modelDecoder, subscriptions, update, view)

import Array exposing (Array)
import Browser.Events
import DecoderUtil exposing (optionalPageDecoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Ports exposing (notifyPageChange)


type PageEntry
    = Single String
    | Double String String


type alias Model =
    { name : String
    , path : String
    , pages : Array PageEntry
    , currentPage : Int
    }


type alias ImageClickPayload =
    { offset : Float
    , width : Float
    }


type Msg
    = NextPage
    | PreviousPage
    | GoToPage Int
    | JoinWithNext
    | JoinWithPrevious
    | Split
    | Swap
    | NoOp


modelDecoder : D.Decoder Model
modelDecoder =
    D.map4 Model
        (D.field "name" D.string)
        (D.field "path" D.string)
        (D.field "pages" <|
            D.array <|
                D.oneOf
                    [ D.map Single D.string
                    , D.map2 Double (D.index 0 D.string) (D.index 1 D.string)
                    ]
        )
        (optionalPageDecoder "currentPage")


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NextPage ->
            update (GoToPage (model.currentPage + 1)) model

        PreviousPage ->
            update (GoToPage (model.currentPage - 1)) model

        GoToPage page ->
            if page <= Array.length model.pages && page > 0 && page /= model.currentPage then
                ( { model | currentPage = page }, notifyPageChange { currentPage = page, path = model.path } )

            else
                ( model, Cmd.none )

        JoinWithNext ->
            case ( Array.get (model.currentPage - 1) model.pages, Array.get model.currentPage model.pages ) of
                ( Just (Single left), Just (Single right) ) ->
                    let
                        head =
                            Array.slice 0 (model.currentPage - 1) model.pages
                                |> Array.push (Double left right)

                        tail =
                            Array.slice (model.currentPage + 1) (Array.length model.pages) model.pages
                    in
                    ( { model
                        | pages = Array.append head tail
                      }
                    , Cmd.none
                    )

                ( _, _ ) ->
                    ( model, Cmd.none )

        JoinWithPrevious ->
            update JoinWithNext { model | currentPage = model.currentPage - 1 }

        Split ->
            case Array.get (model.currentPage - 1) model.pages of
                Just (Double left right) ->
                    let
                        head =
                            Array.slice 0 (model.currentPage - 1) model.pages
                                |> Array.push (Single left)
                                |> Array.push (Single right)

                        tail =
                            Array.slice model.currentPage (Array.length model.pages) model.pages
                    in
                    ( { model
                        | pages = Array.append head tail
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        Swap ->
            case Array.get (model.currentPage - 1) model.pages of
                Just (Double left right) ->
                    ( { model
                        | pages = Array.set (model.currentPage - 1) (Double right left) model.pages
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        keyPressed key =
            case key of
                "ArrowLeft" ->
                    PreviousPage

                "ArrowRight" ->
                    NextPage
                
                "Home" ->
                    GoToPage 1
                
                "End" ->
                    GoToPage (Array.length model.pages)

                _ ->
                    NoOp

        keyDecoder : D.Decoder Msg
        keyDecoder =
            D.field "key" D.string
                |> D.andThen (keyPressed >> D.succeed)
    in
    Browser.Events.onKeyDown keyDecoder


view : Model -> Html Msg
view model =
    let
        pageItem ( index, _ ) =
            div
                [ onClick <| GoToPage (index + 1)
                , classList [ ( "active", index < model.currentPage ) ]
                ]
                [ p [] [ text <| String.fromInt (index + 1) ] ]

        pagesBar =
            div
                [ id "pages-bar" ]
                (List.map pageItem <|
                    Array.toIndexedList model.pages
                )

        currentPage =
            case Array.get (model.currentPage - 1) model.pages of
                Just (Single image) ->
                    [ img
                        [ src image
                        , style "width" "100%"
                        ]
                        []
                    ]

                Just (Double left right) ->
                    let
                        singleImage source =
                            img
                                [ src source
                                , style "width" "50%"
                                ]
                                []
                    in
                    List.map singleImage [ left, right ]

                _ ->
                    [ p [] [ text "Error getting page" ] ]

        decideWhichPage : ImageClickPayload -> D.Decoder Msg
        decideWhichPage payload =
            D.succeed <|
                if payload.offset < (payload.width / 2) then
                    PreviousPage

                else
                    NextPage

        handleOnClick =
            D.map2
                ImageClickPayload
                (D.field "offsetX" D.float)
                (D.at [ "target", "clientWidth" ] D.float)
                |> D.andThen decideWhichPage
                |> D.map (\msg -> ( msg, True ))
    in
    div
        []
        [ div
            [ id "page-container"
            , Html.Events.stopPropagationOn "click" handleOnClick
            , Html.Events.preventDefaultOn "contextmenu" <| D.succeed ( NoOp, True )
            ]
            currentPage
        , pagesBar
        ]
