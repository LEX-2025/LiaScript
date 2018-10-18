port module Lia.Effect.Update exposing (Msg(..), has_next, has_previous, init, next, previous, subscriptions, update)

import Date exposing (Date)
import Lia.Effect.Model exposing (Map, Model, current_comment, get_all_javascript, get_javascript)
import Lia.Utils
import Task


port speech2js : List String -> Cmd msg


port speech2elm : (( String, String ) -> msg) -> Sub msg


type Msg
    = Init Bool
    | Next
    | Previous
    | Speak
    | SpeakRslt ( String, String )
    | Rendered Bool (Maybe Date)


update : Msg -> Bool -> Model -> ( Model, Cmd Msg )
update msg sound model =
    case msg of
        Init run_all_javascript ->
            ( model, Task.perform (Just >> Rendered run_all_javascript) Date.now )

        Next ->
            if has_next model then
                { model | visible = model.visible + 1 }
                    |> execute False 100
                    |> update Speak sound

            else
                ( model, Cmd.none )

        Previous ->
            if has_previous model then
                { model | visible = model.visible - 1 }
                    |> execute False 100
                    |> update Speak sound

            else
                ( model, Cmd.none )

        Speak ->
            let
                d =
                    Lia.Utils.scrollIntoView "focused"
            in
            case ( sound, current_comment model ) of
                ( True, Just ( comment, narrator ) ) ->
                    ( { model | speaking = True }, speech2js [ "speak", narrator, comment ] )

                ( True, Nothing ) ->
                    ( model, speech2js [ "cancel" ] )

                ( False, Just ( comment, narrator ) ) ->
                    if model.speaking then
                        ( { model | speaking = False }, speech2js [ "cancel" ] )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SpeakRslt ( "end", msg ) ->
            ( { model | speaking = False }, Cmd.none )

        SpeakRslt ( "error", msg ) ->
            let
                error =
                    Debug.log "TTS error: " msg
            in
            ( { model | speaking = False }, Cmd.none )

        Rendered run_all_javascript _ ->
            model
                |> execute run_all_javascript 0
                |> update Speak sound

        _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ speech2elm SpeakRslt ]


execute : Bool -> Int -> Model -> Model
execute run_all delay model =
    let
        javascript =
            if run_all then
                get_all_javascript model

            else
                get_javascript model

        c =
            List.map (Lia.Utils.execute delay) javascript
    in
    model


has_next : Model -> Bool
has_next model =
    model.visible < model.effects


has_previous : Model -> Bool
has_previous model =
    model.visible > 0


init : Bool -> Msg
init run_all_javascript =
    Init run_all_javascript


next : Msg
next =
    Next


previous : Msg
previous =
    Previous
