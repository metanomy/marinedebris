'use strict'

import React, {
  StyleSheet,
  Platform,
  Alert,
  Text,
  View,
  TouchableHighlight,
} from 'react-native'

import {UIImagePickerManager} from 'NativeModules'
import DeviceInfo from 'react-native-device-info'
import moment from 'moment'
import * as Env from '../environment'

const App = React.createClass({
  watchID: null,

  getInitialState() {
    return {
      isUploading: false,
      locationAvailable: false,
      lastPosition: null,
    }
  },

  componentDidMount() {
    let locationErrorCount = 0

    const locationSuccess = (lastPosition) => {
      locationErrorCount = 0
      this.setState({
        lastPosition,
        locationAvailable: true,
      })
    }

    const locationError = (error) => {
      locationErrorCount++
      if (locationErrorCount > 1) {
        Alert.alert(
          'Unable to locate you',
          error
        )
        this.setState({
          locationAvailable: false,
        })
      }
    }

    const locationOptions = {enableHighAccuracy: true, timeout: 1000, maximumAge: 1000}

    navigator.geolocation.getCurrentPosition(locationSuccess, locationError, locationOptions)
    this.watchID = navigator.geolocation.watchPosition(locationSuccess, locationError, locationOptions)
  },

  componentWillUnmount: function() {
    navigator.geolocation.clearWatch(this.watchID)
  },

  getFormData(fileData, fileName, fileType) {
    const data = new FormData()
    data.append('key', fileName)
    data.append('AWSAccessKeyId', Env.S3_ACCESS_KEY)
    data.append('acl', 'private')
    data.append('policy', Env.S3_POLICY)
    data.append('signature', Env.S3_SIGNATURE)
    data.append('Content-Type', fileType)
    data.append('success_action_status', '201')
    data.append('file', fileData)
    return data
  },

  uploadFile(data) {
    const server = `https://${Env.S3_BUCKET}.s3.amazonaws.com`
    const xhr = new XMLHttpRequest()
    xhr.onload = () => {
      this.setState({isUploading: false})

      if (xhr.status !== 201) {
        Alert.alert(
          'Upload failed',
          'Expected HTTP 200 OK response, got ' + xhr.status + "/" + xhr.responseText
        )
        return
      }

      if (!xhr.responseText) {
        Alert.alert(
          'Upload failed',
          'No response payload.'
        )
        return
      }

      if (xhr.responseText.indexOf(server) === -1) {
        Alert.alert(
          'Upload failed',
          'Invalid response payload.'
        )
        return
      }
    }
    xhr.onreadystatechange = (e) => {}
    xhr.open('POST', server)
    xhr.send(data)
  },

  handlePress(trashType) {
    UIImagePickerManager.launchCamera({
      mediaType: 'photo',
      maxWidth: 1280,
      maxHeight: 1280,
      quality: 0.8,
      noData: true,
    }, (response) => {
      if (response.didCancel) {
        console.log('User cancelled image picker')
        return
      }

      if (response.error) {
        console.log('UIImagePickerManager Error: ', response.error)
        Alert.alert(
          'Unable to access camera',
          response.error,
        )
        return
      }

      const {lastPosition} = this.state

      if (!lastPosition) {
        console.log('Unable to get location')
        Alert.alert(
          'Unable to upload photo.',
          'No location available. Please check that the GPS is enabled.'
        )
        return
      }

      const fileName = [
        moment().format('YYYY_MM_DD_HH_mm_ss'),
        // Platform.OS,
        // DeviceInfo.getDeviceName(),
        trashType.toLowerCase(),
      ].join('-')

      const geoJSON = {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [lastPosition.coords.longitude, lastPosition.coords.latitude],
        },
        properties: {
          timestamp: lastPosition.timestamp,
          heading: lastPosition.coords.heading,
          accuracy: lastPosition.coords.accuracy,
          altitude: lastPosition.coords.altitude,
          platform: Platform.OS,
          device: DeviceInfo.getDeviceName(),
          photoUrl: `https://${Env.S3_BUCKET}.s3.amazonaws.com/${fileName}.jpg`,
          trashType,
        },
      }

      this.uploadFile(this.getFormData({uri: response.uri, name: `${fileName}.jpg`, type: 'image/jpeg'}, `${fileName}.jpg`, 'image/jpeg'))
      this.uploadFile(this.getFormData(JSON.stringify(geoJSON), `${fileName}.json`, 'application/json'))

      this.setState({
        isUploading: true,
      })
    })
  },

  render() {
    const trashTypes = ['Fishing Gear', 'Cigarettes', 'Plastic', 'Metal', 'Other']

    return (
      <View style={styles.container}>
        <View style={styles.buttonContainer}>
          {trashTypes.map((type, i) =>
            <TouchableHighlight key={i} onPress={this.handlePress.bind(null, type)} style={styles.button}>
              <Text style={styles.buttonLabel}>
                {type}
              </Text>
            </TouchableHighlight>
          )}
        </View>

        <View style={styles.uploadContainer}>
          <Text style={styles.uploadText}>
            {this.state.isUploading ? (
              'Uploading photo...'
            ) : this.state.locationAvailable ? (
              `Ready`
            ) : (
              'Attempting to get location…'
            )}
          </Text>
        </View>
      </View>
    )
  },
})

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingTop: 44,
    backgroundColor: '#282d32',
  },

  buttonContainer: {
    flex: 1,
    justifyContent: 'center',
  },
  button: {
    justifyContent: 'center',
    height: 50,
    marginHorizontal: 12,
    marginVertical: 3,
    borderRadius: 3,
    backgroundColor: 'rgba(255,255,255,.1)',
  },
  buttonLabel: {
    fontSize: 20,
    textAlign: 'center',
    color: '#fff',
  },

  uploadContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    height: 44,
  },
  uploadText: {
    color: 'rgba(255,255,255,.5)',
  },
})

export default App