import {setBackend} from './backend-registry';
import {webBackend} from './backend.web';

setBackend(webBackend);
