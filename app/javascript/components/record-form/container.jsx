import React, { useEffect } from "react";
import PropTypes from "prop-types";
import { Grid, Box } from "@material-ui/core";
import { useSelector, useDispatch } from "react-redux";
import { makeStyles } from "@material-ui/styles";
import { withRouter } from "react-router-dom";
import { Nav } from "./nav";
import NAMESPACE from "./namespace";
import { RecordForm, RecordFormToolbar } from "./form";
import styles from "./styles.css";
import { fetchForms, fetchRecord } from "./action-creators";
import {
  getFirstTab,
  getFormNav,
  getRecordForms,
  getRecord
} from "./selectors";
import { RECORD_TYPES } from "./constants";

// TODO: Initial form to show
const RecordForms = ({ match, mode }) => {
  let submitForm = null;

  const containerMode = {
    isNew: mode === "new",
    isEdit: mode === "edit",
    isShow: mode === "show"
  };

  const css = makeStyles(styles)();
  const dispatch = useDispatch();
  const { params } = match;
  const recordType = RECORD_TYPES[params.recordType];

  const record =
    containerMode.isEdit || containerMode.isShow
      ? useSelector(state => getRecord(state))
      : null;

  const selectedModule = {
    recordType,
    primeroModule: record ? record.get("module_id") : params.module
  };

  const formNav = useSelector(state => getFormNav(state, selectedModule));
  const forms = useSelector(state => getRecordForms(state, selectedModule));
  const firstTab = useSelector(state => getFirstTab(state, selectedModule));

  const selectedForm = useSelector(state =>
    state.getIn([NAMESPACE, "selectedForm"])
  );

  const handleFormSubmit = e => {
    if (submitForm) {
      submitForm(e);
    }
  };

  const formProps = {
    onSubmit: (values, { setSubmitting }) => {
      setTimeout(() => {
        alert(JSON.stringify(values, null, 2));
        setSubmitting(false);
      }, 400);
    },
    bindSubmitForm: boundSubmitForm => {
      submitForm = boundSubmitForm;
    },
    selectedForm,
    forms,
    mode: containerMode,
    record
  };

  useEffect(() => {
    if (params.id && (containerMode.isShow || containerMode.isEdit)) {
      dispatch(fetchRecord(params.recordType, params.id));
    } else {
      dispatch(fetchForms());
    }
  }, []);

  return (
    <>
      <Grid container>
        <RecordFormToolbar
          {...{
            mode: containerMode,
            params,
            recordType,
            handleFormSubmit,
            shortId: record ? record.get("short_id") : null
          }}
        />
        <Box display="flex" width="100%" height="100%">
          <Box width={255}>
            <Nav {...{ formNav, selectedForm, firstTab }} />
          </Box>
          <Box className={css.divider}>
            <Box className={css.dividerInner} />
          </Box>
          <Box width={680} px={3}>
            {forms && <RecordForm {...formProps} />}
          </Box>
        </Box>
      </Grid>
    </>
  );
};

RecordForms.propTypes = {
  match: PropTypes.object.isRequired,
  mode: PropTypes.string.isRequired
};

export default withRouter(RecordForms);