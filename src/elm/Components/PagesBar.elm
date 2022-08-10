module Components.PagesBar exposing (..)

import Array exposing (Array)
import Html as H
import Html.Attributes as A
import Html.Events as E
import Stateful exposing (Stateful)


type alias Model =
    { pages : Array (Stateful () ())
    , currentPage : Int
    }


type Msg
    = GoToPage Int


type OutMsg
    = PageChange Int


update : Msg -> OutMsg
update msg =
    case msg of
        GoToPage page ->
            PageChange page


view : Model -> H.Html Msg
view model =
    let
        pageItem index item =
            H.div
                [ E.onClick <| GoToPage index
                , A.classList
                    [ ( "active", index <= model.currentPage )
                    , ( "not-asked", Stateful.isNotAsked item )
                    , ( "loading", Stateful.isLoading item )
                    , ( "success", Stateful.isSuccess item )
                    , ( "failure", Stateful.isFailure item )
                    ]
                ]
                [ H.p [] [ H.text <| String.fromInt (index + 1) ] ]
    in
    H.div
        [ A.id "pages-bar" ]
        (Array.toList model.pages |> List.indexedMap pageItem)
