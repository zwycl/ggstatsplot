#' @title Scatterplot with marginal distributions and statistical results
#' @name ggscatterstats
#' @description Scatterplots from `ggplot2` combined with marginal
#'   histograms/boxplots/density plots with statistical details added as a
#'   subtitle.
#'
#' @param label.var Variable to use for points labels. Can be entered either as
#'   a character string (e.g., `"var1"`) or as a bare expression (e.g, `var1`).
#' @param label.expression An expression evaluating to a logical vector that
#'   determines the subset of data points to label. This argument can be entered
#'   either as a character string (e.g., `"y < 4 & z < 20"`) or as a bare
#'   expression (e.g., `y < 4 & z < 20`).
#' @param line.color color for the regression line.
#' @param line.size Size for the regression line.
#' @param point.color,point.size,point.alpha Aesthetics specifying geom point
#'   (defaults: `point.color = "black"`, `point.size = 3`,`point.alpha = 0.4`).
#' @param marginal Decides whether `ggExtra::ggMarginal()` plots will be
#'   displayed; the default is `TRUE`.
#' @param marginal.type Type of marginal distribution to be plotted on the axes
#'   (`"histogram"`, `"boxplot"`, `"density"`, `"violin"`, `"densigram"`).
#' @param marginal.size Integer describing the relative size of the marginal
#'   plots compared to the main plot. A size of `5` means that the main plot is
#'   5x wider and 5x taller than the marginal plots.
#' @param margins Character describing along which margins to show the plots.
#'   Any of the following arguments are accepted: `"both"`, `"x"`, `"y"`.
#' @param xfill,yfill Character describing color fill for `x` and `y` axes
#'   marginal distributions (default: `"#009E73"` (for `x`) and `"#D55E00"` (for
#'   `y`)). If set to `NULL`, manual specification of colors will be turned off
#'   and 2 colors from the specified `palette` from `package` will be selected.
#' @param xalpha,yalpha Numeric deciding transparency levels for the marginal
#'   distributions. Any numbers from `0` (transparent) to `1` (opaque). The
#'   default is `1` for both axes.
#' @param xsize,ysize Size for the marginal distribution boundaries (Default:
#'   `0.7`).
#' @param centrality.para Decides *which* measure of central tendency (`"mean"`
#'   or `"median"`) is to be displayed as vertical (for `x`) and horizontal (for
#'   `y`) lines. Note that mean values corresponds to arithmetic mean and not
#'   geometric mean.
#' @param point.width.jitter,point.height.jitter Degree of jitter in `x` and `y`
#'   direction, respectively. Defaults to `0` (0%) of the resolution of the
#'   data.
#' @inheritParams statsExpressions::expr_corr_test
#' @inheritParams ggplot2::geom_smooth
#' @inheritParams theme_ggstatsplot
#' @inheritParams paletteer::paletteer_d
#' @inheritParams ggbetweenstats
#'
#' @import ggplot2
#'
#' @importFrom dplyr select group_by summarize n arrange if_else desc
#' @importFrom dplyr mutate mutate_at mutate_if
#' @importFrom rlang !! enquo quo_name parse_expr ensym as_name enexpr
#' @importFrom ggExtra ggMarginal
#' @importFrom stats cor.test
#' @importFrom ggrepel geom_label_repel
#' @importFrom tibble as_tibble
#' @importFrom statsExpressions expr_corr_test bf_corr_test
#'
#' @seealso \code{\link{grouped_ggscatterstats}}, \code{\link{ggcorrmat}},
#' \code{\link{grouped_ggcorrmat}}
#'
#' @references
#' \url{https://indrajeetpatil.github.io/ggstatsplot/articles/web_only/ggscatterstats.html}
#'
#' @note
#' The plot uses `ggrepel::geom_label_repel` to attempt to keep labels
#' from over-lapping to the largest degree possible.  As a consequence plot
#' times will slow down massively (and the plot file will grow in size) if you
#' have a lot of labels that overlap.
#'
#' @examples
#'
#' # to get reproducible results from bootstrapping
#' set.seed(123)
#'
#' # creating dataframe with rownames converted to a new column
#' mtcars_new <- mtcars %>%
#'   tibble::rownames_to_column(., var = "car") %>%
#'   tibble::as_tibble(x = .)
#'
#' # simple function call with the defaults
#' ggstatsplot::ggscatterstats(
#'   data = mtcars_new,
#'   x = wt,
#'   y = mpg,
#'   type = "np",
#'   label.var = car,
#'   label.expression = wt < 4 & mpg < 20,
#'   axes.range.restrict = TRUE,
#'   centrality.para = "median",
#'   xfill = NULL
#' )
#' @export

# defining the function
ggscatterstats <- function(data,
                           x,
                           y,
                           type = "pearson",
                           conf.level = 0.95,
                           bf.prior = 0.707,
                           bf.message = TRUE,
                           label.var = NULL,
                           label.expression = NULL,
                           xlab = NULL,
                           ylab = NULL,
                           method = "lm",
                           method.args = list(),
                           formula = y ~ x,
                           point.color = "black",
                           point.size = 3,
                           point.alpha = 0.4,
                           point.width.jitter = 0,
                           point.height.jitter = 0,
                           line.size = 1.5,
                           line.color = "blue",
                           marginal = TRUE,
                           marginal.type = "histogram",
                           marginal.size = 5,
                           margins = c("both", "x", "y"),
                           package = "wesanderson",
                           palette = "Royal1",
                           direction = 1,
                           xfill = "#009E73",
                           yfill = "#D55E00",
                           xalpha = 1,
                           yalpha = 1,
                           xsize = 0.7,
                           ysize = 0.7,
                           centrality.para = NULL,
                           results.subtitle = TRUE,
                           stat.title = NULL,
                           title = NULL,
                           subtitle = NULL,
                           caption = NULL,
                           nboot = 100,
                           beta = 0.1,
                           k = 2,
                           axes.range.restrict = FALSE,
                           ggtheme = ggplot2::theme_bw(),
                           ggstatsplot.layer = TRUE,
                           ggplot.component = NULL,
                           return = "plot",
                           messages = TRUE) {

  #---------------------- variable names --------------------------------

  # ensure the arguments work quoted or unquoted
  x <- rlang::ensym(x)
  y <- rlang::ensym(y)
  label.var <- if (!rlang::quo_is_null(rlang::enquo(label.var))) rlang::ensym(label.var)

  # if `xlab` and `ylab` is not provided, use the variable `x` and `y` name
  if (is.null(xlab)) xlab <- rlang::as_name(x)
  if (is.null(ylab)) ylab <- rlang::as_name(y)

  #----------------------- linear model check ----------------------------

  # subtitle statistics is valid only for linear models, so turn off the
  # analysis if the model is not linear
  # `method` argument can be a string (`"gam"`) or function (`MASS::rlm`)
  method_ch <- paste(deparse(method), collapse = "")

  # check the formula and the method
  if (as.character(deparse(formula)) != "y ~ x" ||
    if (class(method) == "function") {
      method_ch != paste(deparse(lm), collapse = "")
    } else {
      method != "lm"
    }) {
    # turn off the analysis
    results.subtitle <- FALSE

    # tell the user
    message(cat(
      crayon::red("Warning: "),
      crayon::blue("The statistical analysis is available only for linear model\n"),
      crayon::blue("(formula = y ~ x, method = 'lm'). Returning only the plot.\n"),
      sep = ""
    ))
  }

  #----------------------- dataframe ---------------------------------------

  # preparing the dataframe
  data %<>%
    dplyr::filter(.data = ., !is.na({{ x }}), !is.na({{ y }})) %>%
    tibble::as_tibble(.)

  #---------------------------- user expression -------------------------

  # check labeling variable has been entered
  if (!rlang::quo_is_null(rlang::enquo(label.var))) {
    point.labelling <- TRUE

    # is expression provided?
    if (!rlang::quo_is_null(rlang::enquo(label.expression))) {
      expression.present <- TRUE
    } else {
      expression.present <- FALSE
    }

    # creating a new dataframe for showing labels
    if (isTRUE(expression.present)) {
      if (!rlang::quo_is_null(rlang::enquo(label.expression))) {
        label.expression <- rlang::enexpr(label.expression)
      }

      # testing for whether we received bare or quoted
      if (typeof(label.expression) == "language") {
        # unquoted case
        label_data <- dplyr::filter(.data = data, !!label.expression)
      } else {
        # quoted case
        label_data <- dplyr::filter(.data = data, !!rlang::parse_expr(label.expression))
      }
    } else {
      label_data <- data
    }
  } else {
    point.labelling <- FALSE
  }

  #----------------------- creating results subtitle ------------------------

  # adding a subtitle with statistical results
  if (isTRUE(results.subtitle)) {
    subtitle <-
      statsExpressions::expr_corr_test(
        data = data,
        x = {{ x }},
        y = {{ y }},
        nboot = nboot,
        beta = beta,
        type = type,
        conf.level = conf.level,
        conf.type = "norm",
        k = k,
        stat.title = stat.title,
        messages = messages
      )

    # preparing the BF message for null hypothesis support
    if (isTRUE(bf.message)) {
      bf.caption.text <-
        statsExpressions::bf_corr_test(
          data = data,
          x = {{ x }},
          y = {{ y }},
          bf.prior = bf.prior,
          caption = caption,
          output = "caption",
          k = k
        )
    }

    # if bayes factor message needs to be displayed
    if (type %in% c("pearson", "parametric", "p") && isTRUE(bf.message)) {
      caption <- bf.caption.text
    }
  }

  #--------------------------------- basic plot ---------------------------

  # creating jittered positions
  pos <- ggplot2::position_jitter(
    width = point.width.jitter,
    height = point.height.jitter,
    seed = 123
  )

  # if user has not specified colors, then use a color palette
  if (is.null(xfill) || is.null(yfill)) {
    colors <-
      paletteer::paletteer_d(
        package = !!package,
        palette = !!palette,
        n = 2,
        direction = direction,
        type = "discrete"
      )

    # assigning selected colors
    xfill <- colors[1]
    yfill <- colors[2]
  }

  # preparing the scatterplot
  plot <-
    ggplot2::ggplot(data = data, mapping = ggplot2::aes(x = {{ x }}, y = {{ y }})) +
    ggplot2::geom_point(
      color = point.color,
      size = point.size,
      alpha = point.alpha,
      stroke = 0,
      position = pos,
      na.rm = TRUE
    ) +
    ggplot2::geom_smooth(
      method = method,
      method.args = method.args,
      formula = formula,
      se = TRUE,
      size = line.size,
      color = line.color,
      na.rm = TRUE,
      level = conf.level
    ) +
    ggstatsplot::theme_mprl(
      ggtheme = ggtheme,
      ggstatsplot.layer = ggstatsplot.layer
    ) +
    ggplot2::labs(
      x = xlab,
      y = ylab,
      title = title,
      subtitle = subtitle,
      caption = caption
    )

  #----------------------- adding centrality parameters --------------------

  # computing summary statistics needed for displaying labels
  x_mean <- mean(x = data %>% dplyr::pull({{ x }}), na.rm = TRUE)
  x_median <- median(x = data %>% dplyr::pull({{ x }}), na.rm = TRUE)
  y_mean <- mean(x = data %>% dplyr::pull({{ y }}), na.rm = TRUE)
  y_median <- median(x = data %>% dplyr::pull({{ y }}), na.rm = TRUE)
  x_label_pos <- median(
    x = ggplot2::layer_scales(plot)$x$range$range,
    na.rm = TRUE
  )
  y_label_pos <- median(
    x = ggplot2::layer_scales(plot)$y$range$range,
    na.rm = TRUE
  )

  # adding vertical and horizontal lines and attaching labels
  if (!is.null(centrality.para) && !isFALSE(centrality.para)) {
    # choosing the appropriate intercepts for the lines
    if (centrality.para == "mean" || isTRUE(centrality.para)) {
      x.intercept <- x_mean
      y.intercept <- y_mean
      x.vline <- x_mean
      y.vline <- y_label_pos
      x.hline <- x_label_pos
      y.hline <- y_mean
      label.text <- "mean"
    } else {
      x.intercept <- x_median
      y.intercept <- y_median
      x.vline <- x_median
      y.vline <- y_label_pos
      x.hline <- x_label_pos
      y.hline <- y_median
      label.text <- "median"
    }

    # adding lines
    plot <- plot +
      # vertical line
      ggplot2::geom_vline(
        xintercept = x.intercept,
        linetype = "dashed",
        color = xfill,
        size = 1.0,
        na.rm = TRUE
      ) +
      # horizontal line
      ggplot2::geom_hline(
        yintercept = y.intercept,
        linetype = "dashed",
        color = yfill,
        size = 1.0,
        na.rm = TRUE
      )

    # adding labels
    # for vertical line
    plot <- line_labeller(
      plot = plot,
      x = x.vline,
      y = y.vline,
      k = 2,
      color = xfill,
      label.text = label.text,
      line.direction = "vline",
      jitter = 0.25
    )

    # for horizontal line
    plot <- line_labeller(
      plot = plot,
      x = x.hline,
      y = y.hline,
      k = 2,
      line.direction = "hline",
      color = yfill,
      label.text = label.text,
      jitter = 0.25
    )
  }

  #---------------------- range restriction -------------------------------

  # forcing the plots to get cut off at min and max values of the variable
  if (isTRUE(axes.range.restrict)) {
    plot <- plot +
      ggplot2::coord_cartesian(xlim = c(
        min(data %>% dplyr::pull({{ x }}), na.rm = TRUE),
        max(data %>% dplyr::pull({{ x }}), na.rm = TRUE)
      )) +
      ggplot2::coord_cartesian(ylim = c(
        min(data %>% dplyr::pull({{ y }}), na.rm = TRUE),
        max(data %>% dplyr::pull({{ y }}), na.rm = TRUE)
      ))
  }

  #-------------------- adding point labels --------------------------------

  # using geom_repel_label
  if (isTRUE(point.labelling)) {
    plot <- plot +
      ggrepel::geom_label_repel(
        data = label_data,
        mapping = ggplot2::aes(label = {{ label.var }}),
        fontface = "bold",
        color = "black",
        max.iter = 3e2,
        box.padding = 0.35,
        point.padding = 0.5,
        segment.color = "black",
        force = 2,
        position = pos,
        na.rm = TRUE
      )
  }

  # ---------------- adding ggplot component ---------------------------------

  # if any additional modification needs to be made to the plot
  # this is primarily useful for grouped_ variant of this function
  plot <- plot + ggplot.component

  #------------------------- ggMarginal  ---------------------------------

  # creating the `ggMarginal` plot of a given `marginal.type`
  if (isTRUE(marginal)) {
    # adding marginals to plot
    plot <- ggExtra::ggMarginal(
      p = plot,
      type = marginal.type,
      margins = margins,
      size = marginal.size,
      xparams = list(
        fill = xfill,
        alpha = xalpha,
        size = xsize,
        col = "black"
      ),
      yparams = list(
        fill = yfill,
        alpha = yalpha,
        size = ysize,
        col = "black"
      )
    )
  }

  #------------------------- messages  ------------------------------------

  # display warning that this function doesn't produce a ggplot2 object
  if (isTRUE(marginal) && isTRUE(messages)) {
    message(cat(
      crayon::red("Warning: "),
      crayon::blue("This plot can't be further modified with `ggplot2` functions.\n"),
      crayon::blue("In case you want a `ggplot` object, set `marginal = FALSE`."),
      sep = ""
    ))
  }

  # return the final plot
  return(switch(
    EXPR = return,
    "plot" = plot,
    "subtitle" = subtitle,
    "caption" = caption,
    plot
  ))
}
