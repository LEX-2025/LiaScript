port module Lia.Code.Update exposing (Msg(..), subscriptions, update)

import Array exposing (Array)
import Json.Decode as JD
import Lia.Code.Types exposing (..)
import Lia.Helper exposing (ID)
import Lia.Utils


port eval_tx : ( Int, String ) -> Cmd msg


port eval_rx : (( Bool, Int, String ) -> msg) -> Sub msg


subscriptions : Vector -> Sub Msg
subscriptions model =
    Sub.batch [ eval_rx EvalRslt2 ]


type Msg
    = Eval ID
    | Update ID ID String
    | FlipView ID ID
    | EvalRslt2 ( Bool, Int, String )
    | EvalRslt
        (Result
            { id : ID
            , message : String
            , details : JD.Value
            }
            { id : ID
            , message : String
            , details : JD.Value
            }
        )
    | Load ID Int


update : Msg -> Vector -> ( Vector, Cmd Msg )
update msg model =
    case msg of
        Eval idx ->
            case Array.get idx model of
                Just project ->
                    ( update_ idx model (\p -> { p | running = True })
                    , eval_tx
                        ( idx
                        , project.file
                            |> Array.indexedMap (\i f -> ( i, f.code ))
                            |> Array.foldl replace project.evaluation
                        )
                    )

                Nothing ->
                    ( model, Cmd.none )

        EvalRslt (Ok { id, message, details }) ->
            ( details
                |> JD.decodeValue (JD.array JD.value)
                |> Result.withDefault Array.empty
                |> Rslt message
                |> Ok
                |> resulting
                |> update_ id model
            , Cmd.none
            )

        EvalRslt (Err { id, message, details }) ->
            ( details
                |> JD.decodeValue (JD.array JD.value)
                |> Result.withDefault Array.empty
                |> Rslt message
                |> Err
                |> resulting
                |> update_ id model
            , Cmd.none
            )

        Update id_1 id_2 code_str ->
            update_file id_1 id_2 model (\f -> { f | code = code_str }) Cmd.none

        FlipView id_1 id_2 ->
            update_file id_1 id_2 model (\f -> { f | visible = not f.visible }) Cmd.none

        Load idx version ->
            ( update_ idx model (load version), Cmd.none )

        EvalRslt2 ( True, idx, message ) ->
            if message == "[object Object]" then
                ( model, Cmd.none )
            else
                ( Rslt message Array.empty
                    |> Ok
                    |> resulting
                    |> update_ idx model
                , Cmd.none
                )

        EvalRslt2 ( False, idx, message ) ->
            ( Rslt message Array.empty
                |> Err
                |> resulting
                |> update_ idx model
            , Cmd.none
            )


replace : ( Int, String ) -> String -> String
replace ( int, insert ) into =
    into
        |> String.split ("{{" ++ toString int ++ "}}")
        |> String.join insert


update_ : ID -> Vector -> (Project -> Project) -> Vector
update_ idx model f =
    case Array.get idx model of
        Just elem ->
            Array.set idx (f elem) model

        Nothing ->
            model


update_file : ID -> ID -> Vector -> (File -> File) -> Cmd msg -> ( Vector, Cmd msg )
update_file id_1 id_2 model f cmd =
    ( case Array.get id_1 model of
        Just project ->
            case Array.get id_2 project.file of
                Just file ->
                    Array.set id_1 { project | file = Array.set id_2 (f file) project.file } model

                Nothing ->
                    model

        Nothing ->
            model
    , cmd
    )


resulting : Result Rslt Rslt -> Project -> Project
resulting result elem =
    let
        ( code, _ ) =
            elem.version
                |> Array.get elem.version_active
                |> Maybe.withDefault ( Array.empty, noResult )

        e =
            { elem
                | result = result
                , running = False
            }

        new_code =
            e.file |> Array.map .code
    in
    if code == new_code then
        { e
            | version = Array.set e.version_active ( code, result ) e.version
        }
    else
        { e
            | version = Array.push ( new_code, result ) e.version
            , version_active = Array.length e.version
        }


load : Int -> Project -> Project
load version elem =
    if (version >= 0) && (version < Array.length elem.version) then
        let
            ( code, result ) =
                elem.version
                    |> Array.get version
                    |> Maybe.withDefault ( Array.empty, noResult )
        in
        { elem
            | version_active = version
            , file = Array.indexedMap (\i a -> { a | code = Array.get i code |> Maybe.withDefault a.code }) elem.file
            , result = result
        }
    else
        elem
