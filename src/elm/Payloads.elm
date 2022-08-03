module Payloads exposing (..)

import Stateful exposing (Stateful)
import Time exposing (Posix)
import Array exposing (Array)


type alias PortStateful payload =
    Stateful ErrorPayload payload


type alias PortResult payload =
    Result ErrorPayload payload


type alias HistoryEntry =
    { title : String
    , author : String
    , chapter : Maybe Int
    , page : Int
    , path : String
    }


type alias History =
    List HistoryEntry


type alias PageRequest =
    { pages : List String
    , path : String
    }


type alias PageChange =
    { currentPage : Int
    , path : String
    }


type alias PageLoaded =
    { page : String
    , data : String
    }


type alias ErrorPayload =
    { code : String
    , message : String
    }


type alias PageLoadError =
    { code : String
    , message : String
    , page : Maybe String
    }


type Demographic
    = Shounen
    | Shoujo
    | Seinen
    | Josei
    | None


type PublicationStatus
    = Ongoing
    | Completed
    | Hiatus
    | Cancelled


type alias CBChapter =
    { title : Maybe String
    , number : Maybe Float
    , partial : Bool
    , extra : Bool
    , authors : Maybe (List String)
    , artists : Maybe (List String)
    , genres : Maybe (List String)
    , themes : Maybe (List String)
    , releaseDate : Maybe Posix
    , tags : Maybe (List String)
    , synopsis : Maybe String
    , oneshot : Bool
    }


type alias CBInfo =
    { title : String
    , authors : Maybe (List String)
    , artists : Maybe (List String)
    , genres : Maybe (List String)
    , themes : Maybe (List String)
    , demographic : Maybe Demographic
    , releaseDate : Maybe Posix
    , endTime : Maybe Posix
    , status : Maybe PublicationStatus
    , tags : Maybe (List String)
    , synopsis : Maybe String
    , oneshot : Bool
    , chapters : Maybe (List CBChapter)
    }


type alias CBFile =
    { pages : Array String
    , path : String
    , lastPageRead : Maybe String
    , thumbnail : Maybe String
    , info : Maybe CBInfo
    }
