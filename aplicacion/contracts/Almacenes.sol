pragma solidity 0.6.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./ComunidadesAutonomas.sol";
import "./SuministrosMedicos.sol";
import "./AccesoBlockchain.sol";
import "./Privado.sol";

/**
    @title Contrato que gestiona a los almacenes
    @author Manuel Ros Rodriguez
    @notice Contrato que se encarga de gestionar la funcionalidad relacionada
            con los almacenes
*/
contract Almacenes is Privado {
    using EnumerableSet for EnumerableSet.UintSet;

    struct almacen {
        string comunidad;
        string informacion;
        EnumerableSet.UintSet suministros;
        mapping(string => uint) unidadesSuministro;
    }

    struct distritoSanitario {
        uint poblacion;
        bool esValido;
        mapping(string => uint) unidadesSuministroAsignadas;
    }

    address[] private almacenes;
    mapping(address => almacen) private informacionAlmacen;

    address[] private distritosSanitarios;
    mapping(address => distritoSanitario) private informacionDistritoSanitario;

    SuministrosMedicos private contratoSuministros;
    ComunidadesAutonomas private contratoComunidades;
    AccesoBlockchain private contratoAcceso;

    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo enviadas por los contratos que conoce
    */
    modifier soloContratos {
        require(msg.sender == address(contratoSuministros) ||
                msg.sender == address(contratoComunidades) ||
                msg.sender == address(contratoAcceso), "Recibida llamada de contrato no autorizado");
        _;
    }

    /**
        @notice Cambia el contrato ComunidadesAutonomas con el que se comunica este contrato
        @param direccionComunidades La direccion del nuevo contrato ComunidadesAutonomas
    */
    function cambiarContratoComunidades(ComunidadesAutonomas direccionComunidades) external soloCuentaAutorizada soloParado {
        contratoComunidades = direccionComunidades;
    }

    /**
        @notice Cambia el contrato SuministrosMedicos con el que se comunica este contrato
        @param direccionSuministros La direccion del nuevo contrato SuministrosMedicos
    */
    function cambiarContratoSuministros(SuministrosMedicos direccionSuministros) external soloCuentaAutorizada soloParado {
        contratoSuministros = direccionSuministros;
    }

    /**
        @notice Cambia el contrato AccesoBlockchain del que recibe llamadas
        @param direccionAcceso La direccion del nuevo contrato AccesoBlockchain
    */
    function cambiarContratoAcceso(AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado {
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Inicializa el contrato, asignandole las direcciones de los contratos con los que interactuara
        @param direccionSuministros La direccion del contrato SuministrosMedicos
        @param direccionComunidades La direccion del contrato ComunidadesAutonomas
        @param direccionAcceso La direccion del contrato AccesoBlockchain
    */
    function inicializar(SuministrosMedicos direccionSuministros, ComunidadesAutonomas direccionComunidades,
        AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado
    {
        contratoSuministros = direccionSuministros;
        contratoComunidades = direccionComunidades;
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Anade un nuevo almacen (que es tambien una cuenta) al sistema
        @param direccionAlmacen Direccion (identificador) del almacen
        @param comunidad El nombre (identificador) de la comunidad autonoma a la que pertenece
        @param informacion Informacion del almacen
        @param esDistritoSanitario Nos indica si el almacen es ademas un distrito sanitario
        @param poblacion La poblacion del distrito sanitario (solo si es un distrito sanitario)
    */
    function anadirAlmacen(address direccionAlmacen, string calldata comunidad, string calldata informacion,
         bool esDistritoSanitario, uint poblacion) external soloContratos puedeParar  {
        require(!perteneceAlmacen(direccionAlmacen), "Error 400: Almacen ya incluido");
        require(contratoComunidades.perteneceComunidad(comunidad), "Error 400: Comunidad autonoma no encontrada");

        EnumerableSet.UintSet memory suministros;
        informacionAlmacen[direccionAlmacen] = almacen(comunidad, informacion, suministros);

        if (esDistritoSanitario) {
            distritosSanitarios.push(direccionAlmacen);
            informacionDistritoSanitario[direccionAlmacen] = distritoSanitario(poblacion, true);
            contratoComunidades.actualizarPoblacion(comunidad, int(poblacion));
        } else
            almacenes.push(direccionAlmacen);
    }

    /**
        @notice Comprueba si el almacen indicado esta incluido en el sistema
        @param direccionAlmacen La direccion (identificador) del almacen
        @return si pertenece o no mediante un bool
    */
    function perteneceAlmacen(address direccionAlmacen) private view puedeParar returns (bool) {
        if (bytes(informacionAlmacen[direccionAlmacen].comunidad).length == 0)
            return false;
        else
            return true;
    }

    /**
        @notice Comprueba si el almacen indicado es un distrito sanitario
        @param direccionAlmacen La direccion (identificador) del almacen
        @return si es un distrito sanitario o no mediante un bool
    */
    function esDistritoSanitario(address direccionAlmacen) private view puedeParar returns (bool) {
        if (informacionDistritoSanitario[direccionAlmacen].esValido)
            return true;
        else
            return false;
    }

    /**
        @notice Anade un nuevo suministro al sistema (El suministro acaba de llegar a Espana)
        @param direccionAlmacen Direccion (identificador) del almacen en el que se encuentra el
                suministro
        @param idSuministro El identificador del suministro
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
        @param preasignado La comunidad autonoma a la que esta preasignada, puede estar vacio
                (y en este caso no tiene ninguna comunidad preasignada)
    */
    function registrarSuministro(address direccionAlmacen, uint idSuministro, string calldata tipoSuministro,
            uint tamanoSuministro, string calldata preasignado) external soloContratos puedeParar  returns (address)
    {
        require(perteneceAlmacen(direccionAlmacen), "Error 400: Almacen no encontrado");

        informacionAlmacen[direccionAlmacen].suministros.add(idSuministro);
        informacionAlmacen[direccionAlmacen].unidadesSuministro[tipoSuministro] += tamanoSuministro;

        string memory comunidad = "";
        if (bytes(preasignado).length != 0) {
            require(contratoComunidades.perteneceComunidad(preasignado), "Error 400: Comunidad autonoma preasignada no encontrada");
            comunidad = preasignado;
        } else
            comunidad = contratoComunidades.repartirComunidades(tipoSuministro);

        address distrito = repartirDistritos(comunidad, tipoSuministro);
        informacionDistritoSanitario[distrito].unidadesSuministroAsignadas[tipoSuministro] += tamanoSuministro;
        contratoComunidades.registrarSuministro(tipoSuministro, tamanoSuministro, comunidad);

        return distrito;
    }

    /**
        @notice Asigna al suministro que acaba de llegar a Espana un distrito sanitario que se
                encuentra en la comunidad autonoma indicada utilizando el siguiente criterio:
                Partiendo de la poblacion y las unidades de este tipo de suministro que tiene
                cada distrito sanitario se escoge el distrito con mayor necesidad
        @param comunidad El nombre (identificador) de la comunidad autonoma
        @param tipoSuministro El tipo de suministro
        @return el distrito sanitario asignado al suministro
    */
    function repartirDistritos(string memory comunidad, string calldata tipoSuministro) private view puedeParar returns (address) {
        address[] memory distritosComunidad = getDistritosComunidad(comunidad);
        require(distritosComunidad.length != 0, "Error 400: La comunidad autonoma no tiene distritos sanitarios");

        int suministrosNecesariosMaximos = int(informacionDistritoSanitario[distritosComunidad[0]].poblacion) -
            int(informacionDistritoSanitario[distritosComunidad[0]].unidadesSuministroAsignadas[tipoSuministro]);
        address direccionDistrito = distritosComunidad[0];

        for (uint i=0; i<distritosComunidad.length; i++){
            int suministrosNecesarios = int(informacionDistritoSanitario[distritosComunidad[i]].poblacion) -
                int(informacionDistritoSanitario[distritosComunidad[i]].unidadesSuministroAsignadas[tipoSuministro]);

            if (suministrosNecesariosMaximos < suministrosNecesarios){
                suministrosNecesariosMaximos = suministrosNecesarios;
                direccionDistrito = distritosComunidad[i];
            }
        }

        return direccionDistrito;
    }

    /**
        @notice Comprueba si el suministro indicado se encuentra en el almacen indicado
        @param idSuministro El identificador del suministro
        @param direccionAlmacen La direccion (identificador) del almacen
        @return si el almacen indicado contiene al suministro indicado o no
                mediante un bool
    */
    function contieneSuministro(uint idSuministro, address direccionAlmacen) private view puedeParar returns (bool) {
        if (informacionAlmacen[direccionAlmacen].suministros.contains(idSuministro))
            return true;
        else
            return false;
    }

    /**
        @notice Gestiona la salida de un suministro de un almacen
        @param origen Direccion (identificador) del almacen del que ha salido
        @param idSuministro El identificador del suministro
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
    */
    function notificarSalidaAlmacen(address origen, uint idSuministro, string calldata tipoSuministro, uint tamanoSuministro) external soloContratos puedeParar {
        require(perteneceAlmacen(origen), "Error 400: Almacen no encontrado");
        require(contieneSuministro(idSuministro, origen), "Error 400: Almacen no contiene el suministro indicado");

        informacionAlmacen[origen].suministros.remove(idSuministro);
        informacionAlmacen[origen].unidadesSuministro[tipoSuministro] -= tamanoSuministro;
    }

    /**
        @notice Gestiona la llegada de un suministro a un almacen
        @param destino Direccion (identificador) del almacen al que ha llegado el suministro
        @param idSuministro El identificador del suministro (El suministro debe de haber notificado
                su salida previamente)
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
    */
    function notificarLlegadaAlmacen(address destino, uint idSuministro, string calldata tipoSuministro, uint tamanoSuministro) external soloContratos puedeParar  {
        require(perteneceAlmacen(destino), "Error 400: Almacen no encontrado");

        informacionAlmacen[destino].suministros.add(idSuministro);
        informacionAlmacen[destino].unidadesSuministro[tipoSuministro] += tamanoSuministro;
    }

    /**
        @notice Gestiona la apertura de un suministro
        @param idSuministro El identificador del suministro
        @param direccionAlmacen Direccion (identificador) del almacen en el que se encuentra
                el suministro (Si este almacen no es el distrito sanitario asignado al suministro
                se lanzara una excepcion)
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
    */
    function utilizarSuministro(uint idSuministro, address direccionAlmacen, string calldata tipoSuministro,
            uint tamanoSuministro) external soloContratos puedeParar
    {
        require(perteneceAlmacen(direccionAlmacen), "Error 400: Almacen no encontrado");
        require(contieneSuministro(idSuministro, direccionAlmacen), "Error 400: Almacen no contiene el suministro indicado");

        informacionAlmacen[direccionAlmacen].suministros.remove(idSuministro);
        informacionAlmacen[direccionAlmacen].unidadesSuministro[tipoSuministro] -= tamanoSuministro;
        informacionDistritoSanitario[direccionAlmacen].unidadesSuministroAsignadas[tipoSuministro] -= tamanoSuministro;

        contratoComunidades.utilizarSuministro(tipoSuministro, tamanoSuministro, informacionAlmacen[direccionAlmacen].comunidad);
    }

    /**
        @notice Modifica el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @param informacion La informacion nueva que se le quiere asignar (En el caso de
                estar vacio no se modificara la informacion del almacen)
        @param poblacion La poblacion nueva que se le quiere asignar. Solo si es un
                distrito sanitario y en el caso de tener valor -1 no se modificara la
                poblacion del distrito sanitario
    */
    function modificarAlmacen(address direccionAlmacen, string calldata informacion, int poblacion) external soloContratos puedeParar {
        require(perteneceAlmacen(direccionAlmacen), "Error 404: Almacen no encontrado");

        if (poblacion != -1) {
            uint poblacionAntigua = informacionDistritoSanitario[direccionAlmacen].poblacion;
            informacionDistritoSanitario[direccionAlmacen].poblacion = uint(poblacion);
            contratoComunidades.actualizarPoblacion(informacionAlmacen[direccionAlmacen].comunidad, poblacion - int(poblacionAntigua));
        }

        if (bytes(informacion).length != 0)
            informacionAlmacen[direccionAlmacen].informacion = informacion;
    }

    /**
        @notice Devuelve los identificadores de todos los distritos sanitarios que pertenecen
                a la comunidad autonoma indicada
        @param comunidad El nombre (identificador) de la comunidad autonoma
        @return los identificadores de todos los distritos sanitarios que pertenecen
                a la comunidad autonoma indicada
    */
    function getDistritosComunidad(string memory comunidad) public view puedeParar returns(address[] memory) {
        address[] memory distritosTemporal = new address[](distritosSanitarios.length);
        uint contador = 0;

        for (uint i=0; i<distritosSanitarios.length; i++) {
            almacen memory distrito = informacionAlmacen[distritosSanitarios[i]];

            if (keccak256(abi.encodePacked(distrito.comunidad)) == keccak256(abi.encodePacked(comunidad))) {
                distritosTemporal[contador] = distritosSanitarios[i];
                contador++;
            }
        }

        address[] memory distritos = new address[](contador);

        while (contador != 0) {
            contador--;
            distritos[contador] = distritosTemporal[contador];
        }

        return distritos;
    }

    /**
        @notice Devuelve contenido JSON con todos los identificadores de los almacenes que hay en el sistema
        @return un JSON (string con contenido JSON) con todos los identificadores de los almacenes
                que hay en el sistema y con el siguiente formato:
                {
                    "resultado":["<almacen1>", "<almacen2>", ...]
                }
    */
    function getAlmacenes() external view puedeParar returns (string memory) {
        string memory almacenesJSON = '{"resultado":[';

        for (uint i=0; i<almacenes.length; i++)
            if (i != (almacenes.length-1))
                almacenesJSON = string(abi.encodePacked(almacenesJSON,'"',
                    direccionAString(almacenes[i]),'",'));
            else
                almacenesJSON = string(abi.encodePacked(almacenesJSON,'"',
                    direccionAString(almacenes[i]),'"'));

        if (almacenes.length > 0 && distritosSanitarios.length > 0)
            almacenesJSON = string(abi.encodePacked(almacenesJSON,','));

        for (uint i=0; i<distritosSanitarios.length; i++)
            if (i != (distritosSanitarios.length-1))
                almacenesJSON = string(abi.encodePacked(almacenesJSON,'"',
                    direccionAString(distritosSanitarios[i]),'",'));
            else
                almacenesJSON = string(abi.encodePacked(almacenesJSON,'"',
                    direccionAString(distritosSanitarios[i]),'"'));

        almacenesJSON = string(abi.encodePacked(almacenesJSON,']}'));

        return (almacenesJSON);
    }

    /**
        @notice Devuelve contenido JSON con toda la informacion del almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return un JSON (string con contenido JSON) con toda la informacion
                del almacen indicado y con el siguiente formato:
                {
                    "direccion":"<direccion>",
                    "comunidad":"<nombre>",
                    "informacion":"<nombre>",
                    "esDistrito":<bool>,
                    "poblacion":<poblacion>, (si es un distrito sanitario)
                    "suministros":[<idSuministro1>,<idSuministro2>, ...],
                    "tiposSuministro":{
                        "<tipo1>":<unidades1>,
                        "<tipo2>":<unidades2>,
                        ...
                    }
                }
    */
    function getInformacionAlmacen(address direccionAlmacen) external view puedeParar returns (string memory) {
        require(perteneceAlmacen(direccionAlmacen), "Error 404: Almacen no encontrado");

        string memory informacion;

        almacen storage datosAlmacen;
        datosAlmacen = informacionAlmacen[direccionAlmacen];

        informacion = string(abi.encodePacked('{"direccion":"',direccionAString(direccionAlmacen),'",',
                                        '"comunidad":"',datosAlmacen.comunidad,'",',
                                        '"informacion":"',datosAlmacen.informacion,'",'));


        if (esDistritoSanitario(direccionAlmacen)) {
            informacion = string(abi.encodePacked(informacion,'"esDistrito":true,',
                                    '"poblacion":',Strings.toString(
                                    informacionDistritoSanitario[direccionAlmacen].poblacion),
                                    ','));
        } else
            informacion = string(abi.encodePacked(informacion,'"esDistrito":false,'));


        informacion = string(abi.encodePacked(informacion,'"suministros":['));

        for (uint i=0; i<datosAlmacen.suministros.length(); i++)
            if (i != (datosAlmacen.suministros.length()-1))
                informacion = string(abi.encodePacked(informacion, Strings.toString(datosAlmacen.suministros.at(i)), ','));
            else
                informacion = string(abi.encodePacked(informacion, Strings.toString(datosAlmacen.suministros.at(i))));

        informacion = string(abi.encodePacked(informacion,'],'));

        uint tamanoTipos = contratoSuministros.getTiposSuministroTamano();
        informacion = string(abi.encodePacked(informacion,'"tiposSuministro":{'));

        for (uint i=0; i<tamanoTipos; i++)
            if (i != (tamanoTipos-1))
                informacion = string(abi.encodePacked(informacion,'"',contratoSuministros.getTipoSuministroIndice(i),
                    '":',Strings.toString(datosAlmacen.unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)]),
                    ','));
            else
                informacion = string(abi.encodePacked(informacion,'"',contratoSuministros.getTipoSuministroIndice(i),
                    '":',Strings.toString(datosAlmacen.unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)])));

        informacion = string(abi.encodePacked(informacion,'}}'));

        return (informacion);
    }

    /**
        @notice Devuelve las unidades en total que tiene el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return las unidades en total que tiene el almacen indicado
    */
    function getUnidadesAlmacen(address direccionAlmacen) external view puedeParar returns (uint) {
        require(perteneceAlmacen(direccionAlmacen), "Error 404: Almacen no encontrado");
        uint unidades = 0;

        uint tamanoTipos = contratoSuministros.getTiposSuministroTamano();

        for (uint i=0; i<tamanoTipos; i++)
            unidades += informacionAlmacen[direccionAlmacen].
                unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)];

        return (unidades);
    }

    /**
        @notice Devuelve las unidades de un tipo de suministro especifico que
                tiene el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @param tipoSuministro El tipo de suministro
        @return las unidades de un tipo de suministro especifico que tiene el almacen indicado
    */
    function getUnidadTipoAlmacen(address direccionAlmacen, string calldata tipoSuministro) external view puedeParar returns (uint) {
        require(perteneceAlmacen(direccionAlmacen), "Error 404: Almacen no encontrado");
        require(contratoSuministros.perteneceTipoSuministro(tipoSuministro), "Error 404: Tipo de suministro no encontrado");
        return (informacionAlmacen[direccionAlmacen].unidadesSuministro[tipoSuministro]);
    }

    /**
        @notice Devuelve la comunidad autonoma a la que pertenece el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return la comunidad autonoma a la que pertenece el almacen indicado
    */
    function getComunidadAlmacen(address direccionAlmacen) external view puedeParar returns (string memory) {
        return (informacionAlmacen[direccionAlmacen].comunidad);
    }


    /**
        @notice Devuelve contenido JSON con las unidades por tipo de suministro que tiene el
                almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return un JSON (string con contenido JSON) con las unidades por tipo de
                suministro que tiene el almacen indicado y con el siguiente formato:
                {
                    "<tipo1>":<unidades1>,
                    "<tipo2>":<unidades2>,
                    ...
                }
    */
    function getUnidadesTiposAlmacen(address direccionAlmacen) external view puedeParar returns (string memory) {
        require(perteneceAlmacen(direccionAlmacen), "Error 404: Almacen no encontrado");

        string memory informacion = '{';
        uint tamanoTipos = contratoSuministros.getTiposSuministroTamano();

        almacen storage datosAlmacen;
        datosAlmacen = informacionAlmacen[direccionAlmacen];

        for (uint i=0; i<tamanoTipos; i++)
            if (i != (tamanoTipos-1))
                informacion = string(abi.encodePacked(informacion,'"',contratoSuministros.getTipoSuministroIndice(i),
                    '":',Strings.toString(datosAlmacen.unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)]),
                    ','));
            else
                informacion = string(abi.encodePacked(informacion,'"',contratoSuministros.getTipoSuministroIndice(i),
                    '":',Strings.toString(datosAlmacen.unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)])));

        informacion = string(abi.encodePacked(informacion,'}'));

        return (informacion);
    }

}
