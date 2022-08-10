module Pages.Reading exposing (Model, Msg, init, subscriptions, update, view)

import Array exposing (Array)
import Browser.Events
import Components.PagesBar
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Payloads
import Ports exposing (notifyPageChange, onMetadataResult, onPageResult, requestMetadata, requestPages)
import Stateful exposing (Stateful(..))


type alias StatefulPageData =
    Payloads.PortStateful String


type alias PageData =
    { path : String
    , data : StatefulPageData
    }


type PageEntry
    = Single PageData
    | Double PageData PageData


type alias ReadingModel =
    { name : String
    , path : String
    , metadata : Maybe Payloads.CBFile
    , pages : Array PageEntry
    , currentPage : Int
    }


type alias Model =
    Payloads.PortStateful ReadingModel


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
    | PageResult (Result Payloads.PageLoadError Payloads.PageLoaded)
    | NoOp
    | MetadataResult (Payloads.PortResult Payloads.CBFile)
    | PagesBarMsg Components.PagesBar.Msg


init : String -> ( Model, Cmd Msg )
init path =
    ( Stateful.Loading, requestMetadata path )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model, msg ) of
        ( Stateful.NotAsked, _ ) ->
            ( model, Cmd.none )

        ( Stateful.Loading, MetadataResult (Ok file) ) ->
            let
                indexOf : Array a -> a -> Maybe Int
                indexOf list item =
                    let
                        recurse : Int -> Maybe Int
                        recurse index =
                            case Array.get index list of
                                Just head ->
                                    if head == item then
                                        Just index

                                    else
                                        recurse (index + 1)

                                _ ->
                                    Nothing
                    in
                    recurse 0

                convertPage : Int -> String -> PageEntry
                convertPage index path =
                    Single
                        { path = path
                        , data =
                            if index < 5 then
                                Loading

                            else
                                NotAsked
                        }

                convertModel : ReadingModel
                convertModel =
                    { pages = Array.indexedMap convertPage file.pages
                    , path = file.path
                    , name = ""
                    , metadata = Nothing
                    , currentPage = Maybe.andThen (indexOf file.pages) file.lastPageRead |> Maybe.withDefault 0
                    }

                first5PagesPayload : Payloads.PageRequest
                first5PagesPayload =
                    { path = file.path, pages = Array.toList <| Array.slice 0 5 file.pages }
            in
            ( Success <| convertModel, requestPages first5PagesPayload )

        ( Stateful.Success payload, NextPage ) ->
            update (GoToPage <| payload.currentPage + 1) model

        ( Stateful.Success payload, PreviousPage ) ->
            update (GoToPage <| payload.currentPage - 1) model

        ( Stateful.Success payload, GoToPage pageIndex ) ->
            let
                unaskedPage page =
                    case page.data of
                        NotAsked ->
                            True

                        _ ->
                            False

                unaskedEntry entry =
                    case entry of
                        Single image ->
                            unaskedPage image

                        Double left right ->
                            unaskedPage left || unaskedPage right

                reducePages entry pageList =
                    case entry of
                        Single page ->
                            page.path :: pageList

                        Double left right ->
                            [ left.path, right.path ] ++ pageList

                currentPagePath =
                    case Array.get pageIndex payload.pages of
                        Just (Single page) ->
                            page.path

                        Just (Double page _) ->
                            page.path

                        _ ->
                            ""

                notifyPageChangeCommand : Cmd msg
                notifyPageChangeCommand =
                    notifyPageChange
                        { title = Nothing
                        , author = Nothing
                        , chapter = Nothing
                        , page = currentPagePath
                        , path = payload.path
                        }

                nextPagesToLoad =
                    Array.slice pageIndex (pageIndex + 5) payload.pages
                        |> Array.filter unaskedEntry
                        |> Array.foldr reducePages []

                requestPagesCommand =
                    requestPages { path = payload.path, pages = nextPagesToLoad }

                finalCommand =
                    if List.isEmpty nextPagesToLoad then
                        notifyPageChangeCommand

                    else
                        Cmd.batch
                            [ notifyPageChangeCommand
                            , requestPagesCommand
                            ]

                updatePageDataState data =
                    case data.data of
                        Stateful.NotAsked ->
                            { data | data = Stateful.Loading }

                        _ ->
                            data

                updateEntryState entry =
                    case entry of
                        Single page ->
                            Single <| updatePageDataState page

                        Double left right ->
                            Double
                                (updatePageDataState left)
                                (updatePageDataState right)

                updatePageArrayState from to =
                    if from >= to then
                        payload.pages

                    else
                        case Array.get from payload.pages of
                            Just entry ->
                                Array.set from (updateEntryState entry) (updatePageArrayState (from + 1) to)

                            Nothing ->
                                payload.pages

                finalModel =
                    { payload | currentPage = pageIndex, pages = updatePageArrayState pageIndex (pageIndex + 5) }
            in
            if pageIndex < Array.length payload.pages && pageIndex >= 0 && pageIndex /= payload.currentPage then
                ( Stateful.Success finalModel, finalCommand )

            else
                ( model, Cmd.none )

        ( Stateful.Success payload, JoinWithNext ) ->
            case ( Array.get payload.currentPage payload.pages, Array.get (payload.currentPage + 1) payload.pages ) of
                ( Just (Single left), Just (Single right) ) ->
                    let
                        head =
                            Array.slice 0 payload.currentPage payload.pages
                                |> Array.push (Double left right)

                        tail =
                            Array.slice (payload.currentPage + 2) (Array.length payload.pages) payload.pages
                    in
                    ( Stateful.Success { payload | pages = Array.append head tail }, Cmd.none )

                ( _, _ ) ->
                    ( model, Cmd.none )

        ( Stateful.Success payload, JoinWithPrevious ) ->
            update JoinWithNext <| Stateful.Success { payload | currentPage = payload.currentPage - 1 }

        ( Stateful.Success payload, Split ) ->
            case Array.get payload.currentPage payload.pages of
                Just (Double left right) ->
                    let
                        head =
                            Array.slice 0 payload.currentPage payload.pages
                                |> Array.push (Single left)
                                |> Array.push (Single right)

                        tail =
                            Array.slice (payload.currentPage + 1) (Array.length payload.pages) payload.pages
                    in
                    ( Stateful.Success { payload | pages = Array.append head tail }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( Stateful.Success payload, Swap ) ->
            case Array.get payload.currentPage payload.pages of
                Just (Double left right) ->
                    ( Stateful.Success { payload | pages = Array.set payload.currentPage (Double right left) payload.pages }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ( Stateful.Success payload, PageResult result ) ->
            let
                findAndUpdate : String -> Payloads.PortStateful String -> Int -> Array PageEntry
                findAndUpdate path data index =
                    case Array.get index payload.pages of
                        Just (Single page) ->
                            if page.path == path then
                                Array.set index (Single { page | data = data }) payload.pages

                            else
                                findAndUpdate path data (index + 1)

                        Just (Double left right) ->
                            if left.path == path then
                                Array.set index (Double { left | data = data } right) payload.pages

                            else if right.path == path then
                                Array.set index (Double left { right | data = data }) payload.pages

                            else
                                findAndUpdate path data (index + 1)

                        Nothing ->
                            payload.pages

                updateDataInPage : String -> Payloads.PortStateful String -> Array PageEntry
                updateDataInPage path data =
                    findAndUpdate path data 0
            in
            case result of
                Ok pageData ->
                    ( Stateful.Success { payload | pages = updateDataInPage pageData.page <| Stateful.Success pageData.data }, Cmd.none )

                Err err ->
                    case err.page of
                        Just path ->
                            ( Stateful.Success { payload | pages = updateDataInPage path <| Stateful.Failure { code = err.code, message = err.message } }, Cmd.none )

                        Nothing ->
                            ( model, Cmd.none )

        ( Success _, PagesBarMsg pbMsg ) ->
            case Components.PagesBar.update pbMsg of
                Components.PagesBar.PageChange index ->
                    update (GoToPage index) model

        ( _, _ ) ->
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
                    GoToPage <| Stateful.withDefault 0 <| Stateful.map (Array.length << .pages) model

                _ ->
                    NoOp

        keyDecoder : D.Decoder Msg
        keyDecoder =
            D.field "key" D.string
                |> D.andThen (keyPressed >> D.succeed)
    in
    case model of
        Stateful.Loading ->
            onMetadataResult MetadataResult

        Stateful.Success _ ->
            Sub.batch
                [ Browser.Events.onKeyDown keyDecoder
                , onPageResult PageResult
                ]

        _ ->
            Sub.none


view : Model -> Html Msg
view model =
    let
        printSinglePage : String -> Payloads.PortStateful String -> Html Msg
        printSinglePage width image =
            case image of
                Stateful.NotAsked ->
                    p [] [ text "The image was not requested" ]

                Stateful.Loading ->
                    p [] [ text "Loading the image" ]

                Stateful.Success source ->
                    img [ src source, style "width" width ] []

                Stateful.Failure err ->
                    p [] [ text <| "Something went wrong while loading the image. Code: " ++ err.code ++ ". Message:" ++ err.message ]

        printCurrentPage payload =
            case Array.get payload.currentPage payload.pages of
                Just (Single image) ->
                    [ printSinglePage "100%" image.data
                    ]

                Just (Double left right) ->
                    List.map .data [ left, right ]
                        |> List.map (printSinglePage "50%")

                _ ->
                    [ p [] [ text <| "The requested page (" ++ String.fromInt (payload.currentPage + 1) ++ ") does not exist" ] ]

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

        mapPageToEmpty : PageEntry -> Stateful () ()
        mapPageToEmpty page =
            case page of
                Single p ->
                    Stateful.mapFailure (always ()) <| Stateful.map (always ()) p.data

                Double l r ->
                    case
                        ( Stateful.mapFailure (always ()) <| Stateful.map (always ()) l.data
                        , Stateful.mapFailure (always ()) <| Stateful.map (always ()) r.data
                        )
                    of
                        ( Loading, _ ) ->
                            Loading

                        ( _, Loading ) ->
                            Loading

                        ( Failure _, _ ) ->
                            Failure ()

                        ( _, Failure _ ) ->
                            Failure ()

                        ( Success _, Success _ ) ->
                            Success ()

                        ( _, _ ) ->
                            Failure ()

        pagesPayload : ReadingModel -> Components.PagesBar.Model
        pagesPayload payload =
            { pages = Array.map mapPageToEmpty payload.pages
            , currentPage = payload.currentPage
            }
    in
    case model of
        Stateful.NotAsked ->
            p [] [ text "Nothing was asked" ]

        Stateful.Loading ->
            p [] [ text "Loading metadata" ]

        Stateful.Success payload ->
            div
                []
                [ div
                    [ id "page-container"
                    , Html.Events.stopPropagationOn "click" handleOnClick
                    , Html.Events.preventDefaultOn "contextmenu" <| D.succeed ( NoOp, True )
                    ]
                    (printCurrentPage payload)
                , Html.map PagesBarMsg (Components.PagesBar.view <| pagesPayload payload)
                ]

        Stateful.Failure err ->
            p [] [ text <| "Something went wrong while loading metadata. Code: " ++ err.code ++ ". Message:" ++ err.message ]
