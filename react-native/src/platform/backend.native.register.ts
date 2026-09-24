import {setBackend} from './backend-registry';
import {nativeBackend} from './backend.native';

setBackend(nativeBackend);
