module Lia.View exposing (view)

import Array exposing (Array)
import Char
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events exposing (onClick, onInput)
import Html.Lazy exposing (lazy2)
import Lia.Chart.View
import Lia.Code.View as Codes
import Lia.Effect.Model as Effect
import Lia.Effect.View as Effects
import Lia.Helper exposing (..)
import Lia.Index.View
import Lia.Inline.Types exposing (Inline)
import Lia.Inline.View as Elem
import Lia.Model exposing (Model)
import Lia.Quiz.View
import Lia.Survey.View
import Lia.Types exposing (..)
import Lia.Update exposing (Msg(..))
import String


view : Model -> Html Msg
view model =
    case model.mode of
        Slides ->
            view_slides model

        Plain ->
            view_plain model


view_plain : Model -> Html Msg
view_plain model =
    let
        f =
            view_slide { model | effect_model = Effect.init_silent }
    in
    Html.div
        [ Attr.class "lia-plain"
        ]
        (List.map f model.slides)


view_slides : Model -> Html Msg
view_slides model =
    let
        loadButton str msg =
            Html.button
                [ onClick msg
                , Attr.class "lia-btn lia-slide-control lia-left"
                ]
                [ Html.text str ]

        content =
            Html.div
                [ Attr.class "lia-slide"
                ]
                [ Html.div
                    [ Attr.class "lia-toolbar"
                    ]
                    (List.append
                        [ Html.button
                            [ onClick ToggleContentsTable
                            , Attr.class "lia-btn lia-toc-control lia-left"
                            ]
                            [ Html.text "toc" ]
                        , loadButton "navigate_before" PrevSlide
                        , loadButton "navigate_next" NextSlide
                        , Html.span [ Attr.class "lia-spacer" ] []
                        ]
                        (view_themes model.theme model.theme_light)
                    )
                , Html.div
                    [ Attr.class "lia-content"
                    ]
                    [ case get_slide model.current_slide model.slides of
                        Just slide ->
                            lazy2 view_slide model slide

                        Nothing ->
                            Html.text ""
                    ]
                ]
    in
    Html.div
        [ Attr.class
            ("lia-canvas lia-theme-"
                ++ model.theme
                ++ " lia-variant-"
                ++ (if model.theme_light then
                        "light"
                    else
                        "dark"
                   )
            )
        ]
        (if model.show_contents then
            [ view_contents model
            , content
            ]
         else
            [ content ]
        )


capitalize : String -> String
capitalize s =
    case String.uncons s of
        Just ( c, ss ) ->
            String.cons (Char.toUpper c) ss

        Nothing ->
            s


view_themes : String -> Bool -> List (Html Msg)
view_themes current_theme light =
    let
        themes =
            [ "default", "amber", "blue", "green", "grey", "purple" ]
    in
    [ Html.span [ Attr.class "lia-labeled lia-right" ]
        [ Html.input [ Attr.type_ "checkbox", onClick ThemeLight, Attr.checked light ] []
        , Html.span [ Attr.class "lia-check-btn" ] [ Html.text "check" ]
        , Html.span [ Attr.class "lia-label" ] [ Html.text "Light Variant" ]
        ]
    , Html.select
        [ onInput Theme
        , Attr.class "lia-right lia-select"
        ]
        (themes
            |> List.map
                (\t ->
                    Html.option
                        [ Attr.value t, Attr.selected (capitalize t ++ " Theme" == current_theme) ]
                        [ Html.text (capitalize t ++ " Theme") ]
                )
        )
    ]


view_contents : Model -> Html Msg
view_contents model =
    let
        f ( n, ( h, i ) ) =
            Html.a
                [ onClick (Load n)
                , Attr.class
                    ("lia-toc-l"
                        ++ toString i
                        ++ (if model.current_slide == n then
                                " lia-active"
                            else
                                ""
                           )
                    )
                , h
                    |> String.split " "
                    |> String.join "_"
                    |> String.append "#"
                    |> Attr.href
                ]
                [ Html.text h ]
    in
    model.slides
        |> get_headers
        |> (\list ->
                case model.index_model.results of
                    Nothing ->
                        list

                    Just index ->
                        list |> List.filter (\( l, x ) -> List.member l index)
           )
        |> List.map f
        |> (\h ->
                Html.div
                    [ Attr.class "lia-toc" ]
                    [ Html.map UpdateIndex <| Lia.Index.View.view model.index_model
                    , Html.div
                        [ Attr.class "lia-content"
                        ]
                        h
                    ]
           )


view_slide : Model -> Slide -> Html Msg
view_slide model slide =
    Html.div
        [ Attr.class "lia-section" ]
        (view_header slide.indentation slide.title
            :: view_body model slide.body
        )


view_header : Int -> String -> Html Msg
view_header indentation title =
    let
        html_title =
            [ Html.text title ]
    in
    case indentation of
        0 ->
            Html.h1
                [ Attr.class "lia-inline"
                , Attr.class "lia-h1"
                ]
                html_title

        1 ->
            Html.h2
                [ Attr.class "lia-inline"
                , Attr.class "lia-h2"
                ]
                html_title

        2 ->
            Html.h3
                [ Attr.class "lia-inline"
                , Attr.class "lia-h3"
                ]
                html_title

        3 ->
            Html.h4
                [ Attr.class "lia-inline"
                , Attr.class "lia-h4"
                ]
                html_title

        4 ->
            Html.h5
                [ Attr.class "lia-inline"
                , Attr.class "lia-h5"
                ]
                html_title

        _ ->
            Html.h6
                [ Attr.class "lia-inline"
                , Attr.class "lia-h6"
                ]
                html_title


view_body : Model -> List Block -> List (Html Msg)
view_body model body =
    let
        f =
            view_block model
    in
    List.map f body


view_block : Model -> Block -> Html Msg
view_block model block =
    case block of
        Paragraph elements ->
            Html.p
                [ Attr.class "lia-inline"
                , Attr.class "lia-paragraph"
                ]
                (List.map (\e -> Elem.view model.effect_model.visible e) elements)

        HLine ->
            Html.hr
                [ Attr.class "lia-inline"
                , Attr.class "lia-horiz-line"
                ]
                []

        Table header format body ->
            view_table model header (Array.fromList format) body

        Quote elements ->
            Html.blockquote
                [ Attr.class "lia-inline"
                , Attr.class "lia-quote"
                ]
                (List.map (\e -> Elem.view model.effect_model.visible e) elements)

        CodeBlock code ->
            Html.map UpdateCode <| Codes.view model.code_model code

        Quiz quiz ->
            Html.map UpdateQuiz <| Lia.Quiz.View.view model.quiz_model quiz

        SurveyBlock survey ->
            Html.map UpdateSurvey <| Lia.Survey.View.view model.survey_model survey

        EBlock idx effect_name sub_blocks ->
            Effects.view_block model.effect_model (view_block model) idx effect_name sub_blocks

        BulletList list ->
            Html.ul
                [ Attr.class "lia-inline"
                , Attr.class "lia-list"
                , Attr.class "lia-unordered"
                ]
                (List.map
                    (\l -> Html.li [] (List.map (\ll -> view_block model ll) l))
                    list
                )

        OrderedList list ->
            Html.ol
                [ Attr.class "lia-inline"
                , Attr.class "lia-list"
                , Attr.class "lia-ordered"
                ]
                (List.map
                    (\l -> Html.li [] (List.map (\ll -> view_block model ll) l))
                    list
                )

        EComment idx comment ->
            Effects.comment model.effect_model (view_block model) idx [ Paragraph comment ]

        Chart chart ->
            Lia.Chart.View.view chart


view_table : Model -> List (List Inline) -> Array String -> List (List (List Inline)) -> Html Msg
view_table model header format body =
    let
        view_row model_ f row =
            row
                |> List.indexedMap (,)
                |> List.map
                    (\( i, col ) ->
                        f
                            [ Attr.align
                                (case Array.get i format of
                                    Just a ->
                                        a

                                    Nothing ->
                                        "left"
                                )
                            ]
                            (col
                                |> List.map (\element -> Elem.view model_.effect_model.visible element)
                            )
                    )
    in
    Html.table
        [ Attr.class "lia-inline"
        , Attr.class "lia-table"
        ]
        (Html.thead
            [ Attr.class "lia-inline"
            , Attr.class "lia-table-head"
            ]
            (view_row model Html.th header)
            :: List.map
                (\r ->
                    Html.tr [ Attr.class "lia-inline", Attr.class "lia-table-row" ]
                        (view_row model Html.td r)
                )
                body
        )



-- SUBSCRIPTIONS
-- HTTP
