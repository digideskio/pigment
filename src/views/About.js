import React, {Component} from 'react';
import {requireServerImage} from '../util';

const kitten = __CLIENT__ ? require('./kitten.jpg') : requireServerImage('./kitten.jpg');

export default class About extends Component {
  state = {
    showKitten: false
  }

  handleToggleKitten() {
    this.setState({showKitten: !this.state.showKitten});
  }

  render() {
    const {showKitten} = this.state;
    return (
      <div>
        <div className="container">
          <h1>About Us</h1>

          <p>This project was orginally created by Erik Rasmussen
            (<a href="https://twitter.com/erikras" target="_blank">@erikras</a>), but has since seen many contributions
            from the open source community. Thank you to <a
              href="https://github.com/erikras/react-redux-universal-hot-example/graphs/contributors"
              target="_blank">all the contributors</a>.
          </p>

          <h3>Images</h3>

          <p>
            Psst! Would you like to see a kitten?

            <button className={'btn btn-' + (showKitten ? 'danger' : 'success')}
                    style={{marginLeft: 50}}
                    onClick={::this.handleToggleKitten}>
              {showKitten ? 'No! Take it away!' : 'Yes! Please!'}</button>
          </p>

          {showKitten && <div><img src={kitten}/></div>}
        </div>
      </div>
    );
  }
}
