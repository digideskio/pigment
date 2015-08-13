import React, {Component, PropTypes} from 'react';
import {Link} from 'react-router';
import {bindActionCreators} from 'redux';
import {connect} from 'react-redux';
import {isLoaded as isAuthLoaded} from '../reducers/auth';
import * as authActions from '../actions/authActions';
import {load as loadAuth} from '../actions/authActions';
import InfoBar from '../components/InfoBar';
import {createTransitionHook} from '../universalRouter';
import {requireServerCss} from '../util';

const styles = __CLIENT__ ?
  require('./App.scss') :
  requireServerCss(require.resolve('./App.scss'));

class App extends Component {
  static propTypes = {
    user: PropTypes.object,
    logout: PropTypes.func
  }

  static contextTypes = {
    router: PropTypes.object.isRequired,
    store: PropTypes.object.isRequired
  };

  componentWillMount() {
    const {router, store} = this.context;
    this.transitionHook = createTransitionHook(store);
    router.addTransitionHook(this.transitionHook);
  }

  componentWillUnmount() {
    const {router, store} = this.context;
    router.removeTransitionHook(this.transitionHook);
  }

  handleLogout(event) {
    event.preventDefault();
    this.props.logout();
  }

  render() {
    const {user} = this.props;
    return (
      <div className={styles.app + " mdl-layout mdl-js-layout mdl-layout--fixed-header"}>
        <nav className="mdl-layout__header">
          <div className="mdl-layout__header-row">
            <Link to="/" className="mdl-layout-title mdl-navigation__link">
              Pigment
            </Link>

            <div className="mdl-layout-spacer" />

            <ul className="mdl-navigation mdl-layout--large-screen-only">
              <li><Link className="mdl-navigation__link" to="/widgets">WIDGETS</Link></li>
              <li><Link className="mdl-navigation__link" to="/survey">SURVEY</Link></li>
              <li><Link className="mdl-navigation__link" to="/about">ABOUT</Link></li>
              <li><Link className="mdl-navigation__link" to="/redirect">REDIRECT</Link></li>
              {!user && <li><Link className="mdl-navigation__link" to="/login">LOGIN</Link></li>}
              {user && <li className="logout-link"><a className="mdl-navigation__link" href="/logout" onClick={::this.handleLogout}>LOGOUT</a></li>}
            </ul>
            {user &&
            <p className={styles.loggedInMessage + ' navbar-text'}>Logged in as <strong>{user.name}</strong>.</p>}
          </div>
        </nav>

        <main className="mdl-layout__content">
          <div className={styles.appContent}>
            {this.props.children}
          </div>

          <InfoBar/>
        </main>

      </div>
    );
  }
}

@connect(state => ({
  user: state.auth.user
}))
export default
class AppContainer {
  static propTypes = {
    user: PropTypes.object,
    dispatch: PropTypes.func.isRequired
  }

  static fetchData(store) {
    const promises = [];
    if (!isAuthLoaded(store.getState())) {
      promises.push(store.dispatch(loadAuth()));
    }
    return Promise.all(promises);
  }

  render() {
    const { user, dispatch } = this.props;
    return <App user={user} {...bindActionCreators(authActions, dispatch)}>
      {this.props.children}
    </App>;
  }
}
