library(testthat)
context("Estimation data")

data(hbatwithsplits, package = "flipExampleData")
hair <- hbatwithsplits
hair1  <- flipTransformations::AsNumeric(hair[, paste0("x",6:18)], binary = FALSE, remove.first = TRUE)
hair1$x1 <- hair$x1
hair1$split60 <- hair$split60
hair1$id <- hair$id


test_that("Single vs multiple imputation",
{
    data("bank", package = "flipExampleData")
    est <- EstimationData(Overall ~ Fees + Branch, bank, missing = "Imputation (replace missing values with estimates)")
    expect_is(est$estimation.data, "data.frame")
    est <- EstimationData(Overall ~ Fees + Branch, bank, missing = "Multiple imputation", m = 10)
    expect_is(est$estimation.data, "list")
    expect_equal(length(est$estimation.data), 10)
})

test_that("Checking that label is retained",
{
    data("bank", package = "flipExampleData")
    attr(bank$Overall, "label") <- "Overall satisfaction"

    est <- EstimationData(Overall ~ Fees + Branch, bank, missing = "Imputation (replace missing values with estimates)")
    expect_is(est$estimation.data, "data.frame")
    est <- EstimationData(Overall ~ Fees + Branch, bank, missing = "Multiple imputation", m = 10)
    expect_is(est$estimation.data, "list")
    expect_equal(length(est$estimation.data), 10)
})


test_that("Duplicate variables", {

    data(phone, package = "flipExampleData")
    expect_error(flipRegression::Regression(q2 ~ q2 + q3, data = phone))
})


zformula <- formula("Overall ~ Fees + Interest + Phone + Branch + Online + ATM")
data(bank, package = "flipExampleData")
sb <- bank$ID > 100
attr(sb, "label") <- "ID greater than 100"
wgt <- bank$ID
wgt[is.na(wgt)] = 0
attr(wgt, "label") <- "ID"
attr(bank$Overall, "label") <- "Overall satisfaction"
attr(bank$Fees, "label") <- "Fees paid"
attr(bank$Online, "label") <- "Online banking"


test_that("DS-2626",
{
    dat2 <- structure(list(Country = structure(c(1L, 4L, 2L, 3L), class = "factor",
                .Label = c("Australia","Denmark", "Fiji", "France"),
                questiontype = "PickOne", name = "Country", label = "Country", question = "Country"),
                  A = structure(c(1L, 2L, 3L, NA), class = "factor", .Label = c("1",
                 "2", "3"), questiontype = "PickOne", name = "A", label = "A", question = "A")),
                class = "data.frame", row.names = c(NA, -4L))
    filt <- c(FALSE, TRUE, TRUE, TRUE)
    expect_warning(EstimationData(~Country + A, data = dat2, subset = filt),
            "Some categories do not appear in the data: 'Country (Country): Australia', 'Country (Country): Fiji', 'A (A): 1'", fixed = TRUE)

    expect_error(res <- TidyRawData(dat2, subset = filt, remove.missing.levels = FALSE), NA)
    expect_equal(levels(dat2[[1]]), levels(res[[1]]))
})

missing.level.test <- data.frame(Y = factor(c(1, 2, 2, 3, 3), labels = LETTERS[1:3]),
                                 X1 = c(NA, 1, NA, 3, 4),
                                 X2 = c(NA, 1, 2, 3, 4),
                                 X3 = c(NA, 3, 2, 1, 4))
expected.dummy.missing.level <- structure(list(Y = structure(c(1L, 1L, 2L, 2L),
                                                             .Label = c("B", "C"),
                                                             class = "factor"),
                                               X1 = c(1, 2.66666666666667, 3, 4),
                                               X2 = c(1, 2, 3, 4),
                                               X3 = c(3, 2, 1, 4),
                                               X1.dummy.var_GQ9KqD7YOf = structure(c(0L, 1L, 0L, 0L),
                                                                                   predictors.matching.dummy = "X1")),
                                          row.names = 2:5, class = "data.frame")
no.level.test <- data.frame(Y  = c(1, 2, 2, 3, 3),
                            X1 = c(NA, 1, NA, 3, 4),
                            X2 = c(NA, 1, 2, 3, 4),
                            X3 = c(NA, 3, 2, 1, 4))
dummy.test <- data.frame(Y = c(1:10), X1 = c(NA, 2:10), X2 = c(1, NA, 3:10), X3 = c(1:2, NA, 4:10))

edge.case.dummy <- data.frame(Y = 1:10, X = 1:10)
edge.case.dummy.miss.outcome <- edge.case.dummy
edge.case.dummy.miss.outcome[1, 1] <- NA

edge.case.dummy.miss.pred <- edge.case.dummy
edge.case.dummy.miss.pred[1, 2] <- NA


test_that("Dummy variable adjustment", {
    expect_warning(missing.level.output <- EstimationData(Y ~ X1 + X2 + X3, data = missing.level.test,
                                                          missing = "Dummy variable adjustment"),
                   "Some categories do not appear in the data: 'Y: A'")
    expect_equal(missing.level.output$estimation.data, expected.dummy.missing.level)
    expect_warning(EstimationData(Y ~ X1 + X2, data = no.level.test), NA)
    expect_error(EstimationData(Y ~ X1 + X2, no.level.test[1:4, ]),
                 "There are fewer observations (2) than there are variables (3)", fixed = TRUE)
    dummy.test.output <- expect_error(EstimationData(Y ~ X1 + X2 + X3, data = dummy.test,
                                                     missing = "Dummy variable adjustment"),
                                      NA)
    expect_equal(dummy.test.output$description,
                 paste0("n = 10 cases used in estimation; ",
                        "missing values of predictor variables have been adjusted using ",
                        "dummy variables;"))
    # Set one case to have missing outcome variable
    dummy.test.missing.outcome <- dummy.test
    dummy.test.missing.outcome[1, 1] <- NA
    dummy.test.output.missing.outcome <- expect_error(EstimationData(Y ~ X1 + X2 + X3, data = dummy.test.missing.outcome,
                                                                     missing = "Dummy variable adjustment"),
                                                      NA)
    expect_equal(dummy.test.output.missing.outcome$description,
                 paste0("n = 9 cases used in estimation of a total sample size of 10; ",
                        "missing values of predictor variables have been adjusted using ",
                        "dummy variables; cases missing an outcome variable have been excluded;"))
    # Remove all predictors in one case
    dummy.test.with.missing.preds <- dummy.test
    dummy.test.with.missing.preds[4, -1] <- NA
    dummy.test.output.missing.predictors <- expect_error(EstimationData(Y ~ X1 + X2 + X3, data = dummy.test.with.missing.preds,
                                                                        missing = "Dummy variable adjustment"),
                                                         NA)
    expect_equal(dummy.test.output.missing.predictors$description,
                 paste0("n = 9 cases used in estimation of a total sample size of 10; ",
                        "missing values of predictor variables have been adjusted using ",
                        "dummy variables; cases missing all predictor variables have been excluded;"))
    # Have cases with missing outcome and all missing predictors.
    dummy.test.miss.preds.outcome <- dummy.test
    dummy.test.miss.preds.outcome[1, 1] <- NA
    dummy.test.miss.preds.outcome[2, -1] <- NA
    dummy.test.output <- expect_error(EstimationData(Y ~ X1 + X2 + X3, data = dummy.test.miss.preds.outcome,
                                                     missing = "Dummy variable adjustment"),
                                      NA)
    expect_equal(dummy.test.output$description,
                 paste0("n = 8 cases used in estimation of a total sample size of 10; ",
                        "missing values of predictor variables have been adjusted using ",
                        "dummy variables; cases missing an outcome variable or missing all predictor variables ",
                        "have been excluded;"))
    # Test edge case
    edge.case.output <- expect_error(EstimationData(Y ~ X, data = edge.case.dummy.miss.outcome,
                                                    missing = "Dummy variable adjustment"),
                                     NA)
    expect_equal(edge.case.output$description,
                 paste0("n = 9 cases used in estimation of a total sample size of 10; ",
                        "cases missing an outcome variable have been excluded;"))
    edge.case.output <- expect_error(EstimationData(Y ~ X, data = edge.case.dummy.miss.pred,
                                                    missing = "Dummy variable adjustment"),
                                     NA)
    expect_equal(edge.case.output$description,
                 paste0("n = 10 cases used in estimation; ",
                        "missing values of predictor variables have been adjusted using ",
                        "dummy variables;"))
})


